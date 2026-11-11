import Foundation
import VitalisCore

/// Keys for the values stored in user defaults.
enum SettingsKey {
    static let refreshInterval = "refreshInterval"
    static let menuBarFields = "menuBarFields"
    static let temperatureUnit = "temperatureUnit"
    static let popoverTransparency = "popoverTransparency"
}

enum SettingsDefault {
    static let refreshInterval: Double = 2
    static let menuBarFields = "temperature,watts"
    /// How much of the popover's glass is taken away, 0...0.6.
    static let popoverTransparency: Double = 0.3
    static let popoverTransparencyRange: ClosedRange<Double> = 0...0.6

    /// The stored transparency, kept inside the allowed range.
    static func clampedTransparency(_ value: Double) -> Double {
        guard value.isFinite else { return popoverTransparency }
        return min(popoverTransparencyRange.upperBound, max(popoverTransparencyRange.lowerBound, value))
    }

    /// The stored refresh interval, or the default if it is missing or not
    /// one of the allowed values.
    static var storedRefreshInterval: Double {
        let stored = UserDefaults.standard.double(forKey: SettingsKey.refreshInterval)
        return Sampler.allowedIntervals.contains(stored) ? stored : refreshInterval
    }
}
