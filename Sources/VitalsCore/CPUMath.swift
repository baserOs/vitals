import Foundation

/// Cumulative CPU time counters for one core, or for all cores added up.
public struct CPUTicks: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public static func + (a: CPUTicks, b: CPUTicks) -> CPUTicks {
        CPUTicks(user: a.user &+ b.user, system: a.system &+ b.system, idle: a.idle &+ b.idle, nice: a.nice &+ b.nice)
    }
}

public enum CPUMath {
    /// Share of time spent busy between two readings, 0...1.
    /// Returns 0 when no time passed or a counter went backwards.
    public static func usage(previous: CPUTicks, current: CPUTicks) -> Double {
        guard current.user >= previous.user, current.system >= previous.system,
              current.idle >= previous.idle, current.nice >= previous.nice else { return 0 }
        let busy = (current.user - previous.user) + (current.system - previous.system) + (current.nice - previous.nice)
        let total = busy + (current.idle - previous.idle)
        guard total > 0 else { return 0 }
        return Double(busy) / Double(total)
    }
}
