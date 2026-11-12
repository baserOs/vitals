import Darwin
import Foundation

/// How much is being downloaded and uploaded right now, from the byte
/// counters macOS keeps for every network interface. Only reads: it
/// sends nothing.
public final class NetworkSource {
    private var previous: [String: InterfaceCounters] = [:]
    private var previousUptime: UInt64 = 0

    public init() {}

    /// Rates since the previous call. nil on the first call and after a
    /// pause, because a rate needs two readings close together.
    public func read(interval: TimeInterval) -> NetworkReading? {
        let current = NetworkSource.counters()
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousUptime > 0 && now > previousUptime ? Double(now - previousUptime) / 1e9 : 0
        let before = previous
        previous = current
        previousUptime = now
        guard !current.isEmpty, SampleGap.isUsable(elapsed: elapsed, interval: interval) else { return nil }
        return NetworkMath.rates(previous: before, current: current, seconds: elapsed)
    }

    /// The byte counters of the Wi-Fi and Ethernet interfaces ("en…").
    /// Loopback and tunnels are left out: a VPN's traffic already passes
    /// through one of these and would be counted twice.
    static func counters() -> [String: InterfaceCounters] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return [:] }
        defer { freeifaddrs(list) }
        var result: [String: InterfaceCounters] = [:]
        var cursor = list
        while let entry = cursor {
            let interface = entry.pointee
            cursor = interface.ifa_next
            // The link-level entry of an interface is the one that carries its counters.
            guard let address = interface.ifa_addr, Int32(address.pointee.sa_family) == AF_LINK,
                  let data = interface.ifa_data, let rawName = interface.ifa_name else { continue }
            let name = String(cString: rawName)
            guard name.hasPrefix("en") else { continue }
            let statistics = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = InterfaceCounters(received: statistics.ifi_ibytes, sent: statistics.ifi_obytes)
        }
        return result
    }
}

/// The bytes one interface has carried, as macOS counts them: 32 bits
/// wide, so they wrap around to zero every 4 GB.
public struct InterfaceCounters: Sendable, Equatable {
    public let received: UInt32
    public let sent: UInt32

    public init(received: UInt32, sent: UInt32) {
        self.received = received
        self.sent = sent
    }
}

public enum NetworkMath {
    /// Bytes per second across every interface present in both readings.
    /// Subtracting with wraparound keeps the result right when a counter
    /// passes 4 GB between the two.
    public static func rates(previous: [String: InterfaceCounters], current: [String: InterfaceCounters],
                             seconds: Double) -> NetworkReading? {
        guard seconds > 0, seconds.isFinite else { return nil }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, now) in current {
            guard let before = previous[name] else { continue }
            received += UInt64(now.received &- before.received)
            sent += UInt64(now.sent &- before.sent)
        }
        return NetworkReading(downloadBytesPerSecond: Double(received) / seconds,
                              uploadBytesPerSecond: Double(sent) / seconds)
    }
}
