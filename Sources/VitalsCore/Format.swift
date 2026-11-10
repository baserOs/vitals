import Foundation

public enum TemperatureUnit: String, Sendable, CaseIterable {
    case celsius
    case fahrenheit
}

/// A value that can be shown in the menu bar.
public enum MenuBarField: String, Sendable, CaseIterable, Identifiable {
    case cpu
    case temperature
    case fan
    case watts
    case memory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return "CPU usage"
        case .temperature: return "Hottest temperature"
        case .fan: return "Fan speed"
        case .watts: return "Power draw"
        case .memory: return "Memory used"
        }
    }

    /// Reads a comma-separated list such as "temperature,watts". Unknown
    /// names are ignored. The result is in display order, without repeats.
    public static func parse(_ text: String) -> [MenuBarField] {
        let chosen = Set(text.split(separator: ",").compactMap {
            MenuBarField(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
        return allCases.filter { chosen.contains($0) }
    }

    public static func serialize(_ fields: [MenuBarField]) -> String {
        let chosen = Set(fields)
        return allCases.filter { chosen.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

/// Turns readings into short text. A missing value is shown as "–".
public enum Format {
    public static let missing = "–"

    public static func temperature(_ celsius: Double?, unit: TemperatureUnit) -> String {
        guard let celsius, celsius.isFinite else { return missing }
        switch unit {
        case .celsius:
            return "\(Int(celsius.rounded()))°C"
        case .fahrenheit:
            return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }

    public static func watts(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(format: "%.1f W", value)
    }

    public static func percent(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return missing }
        return "\(Int((fraction * 100).rounded()))%"
    }

    /// Binary units with one decimal, for example "8.0 GB".
    public static func bytes(_ value: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var amount = Double(value)
        var index = 0
        while amount >= 1024, index < units.count - 1 {
            amount /= 1024
            index += 1
        }
        if index == 0 { return "\(value) B" }
        return String(format: "%.1f %@", amount, units[index])
    }

    public static func rpm(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return "\(Int(value.rounded())) rpm"
    }

    /// The text shown in the menu bar: the chosen fields joined by two spaces.
    public static func menuBar(_ snapshot: Snapshot, fields: [MenuBarField], unit: TemperatureUnit) -> String {
        fields.map { field -> String in
            switch field {
            case .cpu:
                return percent(snapshot.cpu?.total)
            case .temperature:
                return temperature(snapshot.hottest?.celsius, unit: unit)
            case .fan:
                return rpm(snapshot.fastestFan?.rpm)
            case .watts:
                return watts(snapshot.power?.systemWatts)
            case .memory:
                return percent(snapshot.memory?.usedFraction)
            }
        }.joined(separator: "  ")
    }
}
