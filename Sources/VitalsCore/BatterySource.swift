import Foundation
import IOKit

/// Battery state from the battery's own controller.
public final class BatterySource {
    public init() {}

    public func read() -> BatteryReading? {
        var reading: BatteryReading?
        IORegistry.forEachService(named: "AppleSmartBattery") { service in
            guard reading == nil, let properties = IORegistry.properties(of: service) else { return }
            reading = BatterySource.reading(from: properties)
        }
        return reading
    }

    static func reading(from properties: [String: Any]) -> BatteryReading? {
        guard let current = IORegistry.number(properties["CurrentCapacity"]) else { return nil }
        let maximum = IORegistry.number(properties["MaxCapacity"]) ?? 100
        let percent = maximum > 0 ? min(100, max(0, current / maximum * 100)) : 0

        // Amperage is signed milliamps: negative while discharging.
        let milliamps = (properties["Amperage"] as? NSNumber)?.int64Value ?? 0
        let millivolts = IORegistry.number(properties["Voltage"]) ?? 0
        let watts = Double(milliamps) * millivolts / 1_000_000

        var health: Double?
        if let rawMaximum = IORegistry.number(properties["AppleRawMaxCapacity"]),
           let design = IORegistry.number(properties["DesignCapacity"]), design > 0 {
            health = min(100, max(0, rawMaximum / design * 100))
        }

        // Reported in hundredths of a degree Celsius.
        var celsius: Double?
        if let raw = IORegistry.number(properties["Temperature"]) {
            let value = raw / 100
            if SensorCatalog.isPlausible(celsius: value) { celsius = value }
        }

        return BatteryReading(
            percent: percent,
            isCharging: (properties["IsCharging"] as? Bool) ?? false,
            isPluggedIn: (properties["ExternalConnected"] as? Bool) ?? false,
            watts: watts,
            cycleCount: Int(IORegistry.number(properties["CycleCount"]) ?? 0),
            healthPercent: health,
            celsius: celsius
        )
    }
}
