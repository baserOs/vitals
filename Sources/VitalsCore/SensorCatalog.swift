import Foundation

/// Names and groups temperature sensors, and filters out readings that
/// cannot be real.
public enum SensorCatalog {
    /// Readable names for known SMC keys. Keys differ between chip
    /// generations, so this is filled in from a diagnostics report of the
    /// actual Mac. Unknown keys are shown by their raw key.
    static let names: [String: String] = [
        "TaLP": "Airflow left",
        "TaRF": "Airflow right",
        "TB0T": "Battery",
        "TB1T": "Battery 1",
        "TB2T": "Battery 2",
        "TH0x": "SSD",
        "TW0P": "Wireless module",
    ]

    public static func describe(key: String) -> (name: String, group: SensorGroup) {
        if key.hasPrefix("hid:") {
            let name = String(key.dropFirst(4))
            return (name, hidGroup(name))
        }
        return (names[key] ?? key, smcGroup(key))
    }

    private static func smcGroup(_ key: String) -> SensorGroup {
        if key.hasPrefix("Tg") { return .gpu }
        // On some chips "Tf1x" and "Tf2x" are GPU sensors and the other "Tf" keys are CPU cores.
        if key.hasPrefix("Tf1") || key.hasPrefix("Tf2") { return .gpu }
        if key.hasPrefix("Tp") || key.hasPrefix("Te") || key.hasPrefix("Tc") || key.hasPrefix("Tf") { return .cpu }
        if key.hasPrefix("TB") { return .battery }
        if key.hasPrefix("TH") || key.hasPrefix("TN") { return .ssd }
        return .other
    }

    private static func hidGroup(_ name: String) -> SensorGroup {
        let lower = name.lowercased()
        if lower.contains("battery") { return .battery }
        if lower.contains("nand") || lower.contains("ssd") { return .ssd }
        if lower.contains("gpu") { return .gpu }
        if lower.contains("tdie") || lower.contains("cpu") || lower.contains("soc") { return .cpu }
        return .other
    }

    /// True for a temperature a working sensor could report. Exactly 0 is
    /// rejected because unpopulated SMC sensors read 0.
    public static func isPlausible(celsius: Double) -> Bool {
        celsius.isFinite && celsius > 0 && celsius <= 130
    }

    /// Drops implausible readings and repeated keys (the first one wins),
    /// then sorts hottest first.
    public static func clean(_ readings: [TemperatureReading]) -> [TemperatureReading] {
        var seen = Set<String>()
        var kept: [TemperatureReading] = []
        for reading in readings {
            guard !seen.contains(reading.key) else { continue }
            seen.insert(reading.key)
            if isPlausible(celsius: reading.celsius) {
                kept.append(reading)
            }
        }
        return kept.sorted {
            $0.celsius != $1.celsius ? $0.celsius > $1.celsius : $0.key < $1.key
        }
    }
}
