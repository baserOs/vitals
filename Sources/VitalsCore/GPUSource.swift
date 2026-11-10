import Foundation
import IOKit

/// GPU utilisation as reported by the graphics driver.
public final class GPUSource {
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
}
