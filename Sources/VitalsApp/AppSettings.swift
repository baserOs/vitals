import Foundation
import VitalsCore

/// Keys for the values stored in user defaults.
enum SettingsKey {
    static let refreshInterval = "refreshInterval"
    static let menuBarFields = "menuBarFields"
    static let temperatureUnit = "temperatureUnit"
}

enum SettingsDefault {
    static let refreshInterval: Double = 2
    static let menuBarFields = "temperature,watts"

    /// The stored refresh interval, or the default if it is missing or not
    /// one of the allowed values.
    static var storedRefreshInterval: Double {
        let stored = UserDefaults.standard.double(forKey: SettingsKey.refreshInterval)
        return Sampler.allowedIntervals.contains(stored) ? stored : refreshInterval
    }
}
