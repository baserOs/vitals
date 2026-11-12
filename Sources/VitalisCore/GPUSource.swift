import Foundation
import IOKit

/// GPU utilisation as reported by the graphics driver, and which apps
/// are using it.
public final class GPUSource {
    private var previousTimes: [Int32: UInt64] = [:]
    private var previousUptime: UInt64 = 0

    public init() {}

    public func read() -> GPUReading? {
        var highest: Double?
        IORegistry.forEachService(named: "IOAccelerator") { service in
            guard let statistics = IORegistry.property("PerformanceStatistics", of: service) as? [String: Any],
                  let percent = IORegistry.number(statistics["Device Utilization %"]) else { return }
            highest = max(highest ?? 0, percent)
        }
        guard let percent = highest else { return nil }
        return GPUReading(usage: min(1, max(0, percent / 100)))
    }

    /// One entry per connection a process holds to the GPU. The driver
    /// lists them under the accelerator, each with the GPU time it has
    /// used so far.
    public func readClients() -> [GPUClient] {
        var clients: [GPUClient] = []
        IORegistry.forEachService(named: "IOAccelerator") { service in
            IORegistry.forEachChild(of: service) { child in
                guard let creator = IORegistry.property("IOUserClientCreator", of: child) as? String,
                      let owner = GPUShareMath.parseCreator(creator),
                      let usage = IORegistry.property("AppUsage", of: child) as? [[String: Any]] else { return }
                var time: UInt64 = 0
                for entry in usage {
                    if let number = entry["accumulatedGPUTime"] as? NSNumber {
                        time &+= number.uint64Value
                    }
                }
                clients.append(GPUClient(pid: owner.pid, name: owner.name, gpuTime: time))
            }
        }
        return clients
    }

    /// The `limit` apps that used the GPU most since the previous call,
    /// as shares of `utilization`. Empty on the first call and after a
    /// pause, because a share needs two readings close together.
    func readApps(utilization: Double, interval: TimeInterval, resolver: AppResolver, limit: Int) -> [GPUProcessReading] {
        let clients = readClients()
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousUptime > 0 && now > previousUptime ? Double(now - previousUptime) / 1e9 : 0

        var times: [Int32: UInt64] = [:]
        var names: [Int32: String] = [:]
        for client in clients {
            times[client.pid, default: 0] &+= client.gpuTime
            names[client.pid] = client.name
        }
        let before = previousTimes
        previousTimes = times
        previousUptime = now
        guard SampleGap.isUsable(elapsed: elapsed, interval: interval) else { return [] }

        let shares = GPUShareMath.shares(previous: before, current: times, utilization: utilization)
        var perApp: [AppIdentity: Double] = [:]
        for (pid, share) in shares where share > 0 {
            // The driver's name is cut short; ask the system, and fall back to it.
            let name = AppResolver.name(of: pid) ?? names[pid] ?? "pid \(pid)"
            perApp[resolver.identity(pid: pid, name: name), default: 0] += share
        }
        return GPUShareMath.top(perApp, limit: limit)
    }
}

public struct GPUClient: Sendable, Equatable {
    public let pid: Int32
    public let name: String
    /// GPU time used since the connection was opened. Only ever compared
    /// with other clients, so its unit does not matter.
    public let gpuTime: UInt64

    public init(pid: Int32, name: String, gpuTime: UInt64) {
        self.pid = pid
        self.name = name
        self.gpuTime = gpuTime
    }
}

public enum GPUShareMath {
    /// Reads "pid 517, WindowServer", the way the driver names the owner
    /// of a connection.
    public static func parseCreator(_ text: String) -> (pid: Int32, name: String)? {
        guard text.hasPrefix("pid ") else { return nil }
        let rest = text.dropFirst(4)
        let digits = rest.prefix(while: { $0.isNumber })
        guard let pid = Int32(digits), pid > 0 else { return nil }
        var name = rest.dropFirst(digits.count)
        if name.hasPrefix(",") { name = name.dropFirst() }
        return (pid, name.trimmingCharacters(in: .whitespaces))
    }

    /// Splits `utilization` (0...1) between processes in proportion to the
    /// GPU time each used between two readings. A process that is new, or
    /// whose counter went backwards, gets nothing for this round.
    public static func shares(previous: [Int32: UInt64], current: [Int32: UInt64],
                              utilization: Double) -> [Int32: Double] {
        var used: [Int32: Double] = [:]
        var total = 0.0
        for (pid, time) in current {
            guard let before = previous[pid], time > before else { continue }
            let delta = Double(time - before)
            used[pid] = delta
            total += delta
        }
        guard total > 0, utilization.isFinite, utilization > 0 else { return [:] }
        let scale = min(1, utilization) / total
        return used.mapValues { $0 * scale }
    }

    /// The `limit` biggest shares, biggest first. Ties sort by name.
    public static func top(_ perApp: [AppIdentity: Double], limit: Int) -> [GPUProcessReading] {
        let ordered = perApp
            .map { GPUProcessReading(id: $0.key.key, name: $0.key.name, usage: $0.value) }
            .sorted { $0.usage != $1.usage ? $0.usage > $1.usage : $0.id < $1.id }
        return Array(ordered.prefix(max(0, limit)))
    }
}
