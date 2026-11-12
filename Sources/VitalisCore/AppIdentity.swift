import CVitalis
import Darwin
import Foundation

/// The app a process is counted under.
public struct AppIdentity: Sendable, Equatable, Hashable {
    /// The same for every process of one app.
    public let key: String
    public let name: String

    public init(key: String, name: String) {
        self.key = key
        self.name = name
    }
}

/// Works out which app a process belongs to. Pure: no system calls.
public enum AppNaming {
    /// The outermost app bundle a path lies in, so a helper nested inside
    /// "Google Chrome.app" counts as Google Chrome.
    public static func app(inPath path: String) -> AppIdentity? {
        var prefix = ""
        for component in path.split(separator: "/") {
            prefix += "/" + component
            if component.hasSuffix(".app"), component.count > 4 {
                return AppIdentity(key: "app:" + prefix, name: String(component.dropLast(4)))
            }
        }
        return nil
    }

    /// `ownerName` and `ownerPath` describe the process macOS holds
    /// responsible for this one, when that is a different process.
    ///
    /// The owner's app comes first: a browser tab runs from a system
    /// folder, not from inside the browser, and only its owner says which
    /// browser it is. Then the process's own app, then the owner by name,
    /// then the process by name, which also gathers same-named helpers.
    public static func identity(processName: String, path: String?,
                                ownerName: String?, ownerPath: String?) -> AppIdentity {
        if let ownerPath, let app = app(inPath: ownerPath) { return app }
        if let path, let app = app(inPath: path) { return app }
        if let ownerName, !ownerName.isEmpty { return AppIdentity(key: "name:" + ownerName, name: ownerName) }
        return AppIdentity(key: "name:" + processName, name: processName)
    }
}

/// Looks up and remembers the app of each process.
/// Not thread safe: call from one serial queue.
final class AppResolver {
    private var cache: [Int32: (name: String, identity: AppIdentity)] = [:]

    /// `name` is the process's own name. It doubles as the check that a
    /// remembered pid still belongs to the same program.
    func identity(pid: Int32, name: String) -> AppIdentity {
        if let cached = cache[pid], cached.name == name { return cached.identity }
        // Pids come and go; start over rather than grow without bound.
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }

        var ownerName: String?
        var ownerPath: String?
        let owner = vitalis_responsible_pid(pid)
        // Pid 1 starts everything, so it says nothing about which app this is.
        if owner > 1, owner != pid {
            ownerName = AppResolver.name(of: owner)
            ownerPath = AppResolver.path(of: owner)
        }
        let identity = AppNaming.identity(processName: name, path: AppResolver.path(of: pid),
                                          ownerName: ownerName, ownerPath: ownerPath)
        cache[pid] = (name, identity)
        return identity
    }

    static func name(of pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let name = String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        return name.isEmpty ? nil : name
    }

    static func path(of pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        return path.isEmpty ? nil : path
    }
}
