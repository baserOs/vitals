import CVitals
import Foundation

/// Read-only client for the System Management Controller, which holds the
/// temperature, fan and power sensors. It has no write path.
public final class SMCClient {
    private let connection: UInt32
    private var infoCache: [String: (type: String, size: UInt32)] = [:]

    public init?() {
        var opened: UInt32 = 0
        guard vitals_smc_open(&opened) == 0 else { return nil }
        connection = opened
    }

    deinit {
        vitals_smc_close(connection)
    }

    /// Every key the SMC lists. Slow: one call per key.
    public func allKeys() -> [String] {
        let count = vitals_smc_key_count(connection)
        guard count > 0 else { return [] }
        var keys: [String] = []
        keys.reserveCapacity(Int(count))
        var buffer = [CChar](repeating: 0, count: 5)
        for index in 0..<UInt32(count) {
            guard vitals_smc_key_at(connection, index, &buffer) == 0 else { continue }
            keys.append(SMCClient.string(from: buffer))
        }
        return keys
    }

    public func rawRead(_ key: String) -> (type: String, bytes: [UInt8])? {
        guard let info = keyInfo(key) else { return nil }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard vitals_smc_read_bytes(connection, key, info.size, &bytes) == 0 else { return nil }
        return (info.type, Array(bytes.prefix(Int(info.size))))
    }

    public func read(_ key: String) -> (type: String, value: Double)? {
        guard let raw = rawRead(key), let value = SMCDecode.value(type: raw.type, bytes: raw.bytes) else {
            return nil
        }
        return (raw.type, value)
    }

    private func keyInfo(_ key: String) -> (type: String, size: UInt32)? {
        if let cached = infoCache[key] { return cached }
        guard key.utf8.count == 4 else { return nil }
        var type = [CChar](repeating: 0, count: 5)
        var size: UInt32 = 0
        guard vitals_smc_key_info(connection, key, &type, &size) == 0 else { return nil }
        let info = (type: SMCClient.string(from: type), size: size)
        infoCache[key] = info
        return info
    }

    private static func string(from buffer: [CChar]) -> String {
        let bytes = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
