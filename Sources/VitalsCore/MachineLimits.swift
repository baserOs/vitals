import Foundation
import IOKit

/// The most this Mac can draw. These are the tops of the power graphs, so
/// a graph shows how close the machine is to its limit, the way the CPU
/// and memory graphs do with 100%.
public struct MachineLimits: Sendable, Equatable {
    /// The rated output of the biggest charger seen. nil until one is.
    public var adapterWatts: Double?
    /// The most the CPU and GPU can draw together. macOS does not publish
    /// this, so it is estimated from the core counts.
    public var chipWatts: Double

    public init(adapterWatts: Double?, chipWatts: Double) {
        self.adapterWatts = adapterWatts
        self.chipWatts = chipWatts
    }

    /// The most the whole Mac can draw: what its charger delivers, or an
    /// estimate until a charger has been seen.
    public var systemWatts: Double {
        LimitMath.systemWatts(adapterWatts: adapterWatts, chipWatts: chipWatts)
    }

    public var systemIsEstimate: Bool { adapterWatts == nil }

    /// Reads the core counts of this Mac.
    public static func detect(adapterWatts: Double?) -> MachineLimits {
        let chip = LimitMath.chipWatts(
            performanceCores: Sysctl.int("hw.perflevel0.physicalcpu") ?? 0,
            efficiencyCores: Sysctl.int("hw.perflevel1.physicalcpu") ?? 0,
            gpuCores: gpuCoreCount()
        )
        return MachineLimits(adapterWatts: adapterWatts, chipWatts: chip)
    }

    static func gpuCoreCount() -> Int? {
        var count: Int?
        IORegistry.forEachService(named: "IOAccelerator") { service in
            guard let cores = IORegistry.number(IORegistry.property("gpu-core-count", of: service)),
                  cores >= 1, cores <= 512 else { return }
            count = max(count ?? 0, Int(cores))
        }
        return count
    }
}

public enum LimitMath {
    /// Rough peak draw of Apple Silicon: about 4 W per performance core,
    /// 1 W per efficiency core and 1.6 W per GPU core, rounded up to 5 W.
    public static func chipWatts(performanceCores: Int, efficiencyCores: Int, gpuCores: Int?) -> Double {
        guard performanceCores > 0 else { return 30 }
        // Without a GPU core count, assume the smallest GPU sold with that CPU.
        let gpu = gpuCores ?? max(8, performanceCores * 2)
        let watts = 4.0 * Double(performanceCores) + 1.0 * Double(max(0, efficiencyCores)) + 1.6 * Double(gpu)
        return roundUp(watts, step: 5)
    }

    /// The charger rating, or the chip plus 15 W for the display and the rest.
    public static func systemWatts(adapterWatts: Double?, chipWatts: Double) -> Double {
        if let adapterWatts, adapterWatts.isFinite, adapterWatts > 0 { return adapterWatts }
        return roundUp(chipWatts + 15, step: 5)
    }

    /// The top of a graph: the limit, or higher when a reading went above
    /// it, so the line is never cut off.
    public static func ceiling(limit: Double, peak: Double, step: Double) -> Double {
        guard peak.isFinite, peak > limit else { return limit }
        return roundUp(peak * 1.05, step: step)
    }

    static func roundUp(_ value: Double, step: Double) -> Double {
        guard step > 0, value.isFinite else { return value }
        return (value / step).rounded(.up) * step
    }
}
