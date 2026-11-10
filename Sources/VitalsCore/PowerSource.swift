import CVitals
import Foundation

/// Power draw: the whole system and the adapter from the SMC, the CPU and
/// GPU share from the IOReport energy counters.
public final class PowerSource {
    private let smc: SMCClient?

    public init(smc: SMCClient?) {
        self.smc = smc
    }

    /// `interval` is how far apart calls are meant to be, in seconds.
    public func read(interval: TimeInterval) -> PowerReading? {
        var cpu: Double?
        var gpu: Double?
        let sample = EnergyCounters.sample()
        if !sample.channels.isEmpty, SampleGap.isUsable(elapsed: sample.elapsed, interval: interval) {
            for channel in sample.channels {
                guard let watts = EnergyMath.watts(deltaEnergy: channel.delta, unit: channel.unit,
                                                   seconds: sample.elapsed) else { continue }
                if channel.name.hasSuffix("CPU Energy") {
                    cpu = (cpu ?? 0) + watts
                } else if channel.name.hasSuffix("GPU Energy") {
                    gpu = (gpu ?? 0) + watts
                }
            }
        }

        let system = PowerSource.positive(smc?.read("PSTR")?.value, above: 0)
        // On battery the adapter reads zero or noise; treat that as absent.
        let adapter = PowerSource.positive(smc?.read("PDTR")?.value, above: 0.1)

        if system == nil, adapter == nil, cpu == nil, gpu == nil { return nil }
        return PowerReading(systemWatts: system, adapterWatts: adapter, cpuWatts: cpu, gpuWatts: gpu)
    }

    private static func positive(_ value: Double?, above threshold: Double) -> Double? {
        guard let value = value, value.isFinite, value > threshold, value < 1000 else { return nil }
        return value
    }
}

/// The energy counters behind `powermetrics`.
/// Not thread safe: call from one serial queue.
public enum EnergyCounters {
    public struct Channel {
        public let name: String
        public let unit: String
        public let delta: Double
    }

    /// Energy used per channel since the previous call, and the seconds
    /// between the two calls. Empty on the first call or when unavailable.
    public static func sample() -> (channels: [Channel], elapsed: Double) {
        let count = vitals_energy_refresh()
        guard count > 0 else { return ([], 0) }
        var channels: [Channel] = []
        channels.reserveCapacity(Int(count))
        for index in 0..<count {
            guard let namePointer = vitals_energy_channel(index),
                  let unitPointer = vitals_energy_unit(index) else { continue }
            channels.append(Channel(
                name: String(cString: namePointer).trimmingCharacters(in: .whitespaces),
                unit: String(cString: unitPointer).trimmingCharacters(in: .whitespaces),
                delta: vitals_energy_delta(index)
            ))
        }
        return (channels, vitals_energy_elapsed())
    }
}
