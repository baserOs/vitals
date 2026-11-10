import CVitals
import Foundation

/// Every temperature sensor the Mac exposes, from the SMC and from the HID
/// sensor service.
public final class TemperatureSource {
    private let smc: SMCClient?
    private let keys: [String]

    public init(smc: SMCClient?) {
        self.smc = smc
        if let smc = smc {
            // Temperature keys start with "T" and hold a float.
            keys = smc.allKeys().filter { $0.hasPrefix("T") && smc.rawRead($0)?.type == "flt " }
        } else {
            keys = []
        }
    }

    public func read() -> [TemperatureReading] {
        var readings: [TemperatureReading] = []
        if let smc = smc {
            for key in keys {
                guard let value = smc.read(key)?.value else { continue }
                let description = SensorCatalog.describe(key: key)
                readings.append(TemperatureReading(key: key, name: description.name,
                                                   group: description.group, celsius: value))
            }
        }
        for sensor in HIDSensors.read() {
            let key = "hid:" + sensor.name
            let description = SensorCatalog.describe(key: key)
            readings.append(TemperatureReading(key: key, name: description.name,
                                               group: description.group, celsius: sensor.celsius))
        }
        return SensorCatalog.clean(readings)
    }
}

/// Temperature sensors published through the HID event system.
/// Not thread safe: call from one serial queue.
public enum HIDSensors {
    public static func read() -> [(name: String, celsius: Double)] {
        let count = vitals_hid_refresh()
        guard count > 0 else { return [] }
        var sensors: [(name: String, celsius: Double)] = []
        sensors.reserveCapacity(Int(count))
        for index in 0..<count {
            guard let pointer = vitals_hid_name(index) else { continue }
            let name = String(cString: pointer)
            guard !name.isEmpty else { continue }
            sensors.append((name: name, celsius: vitals_hid_celsius(index)))
        }
        return sensors
    }
}
