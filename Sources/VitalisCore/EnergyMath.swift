import Foundation

public enum EnergyMath {
    /// Converts an energy change over a time span into watts.
    /// `unit` is the IOReport label: "mJ", "uJ" or "nJ".
    public static func watts(deltaEnergy: Double, unit: String, seconds: Double) -> Double? {
        guard seconds > 0, deltaEnergy >= 0, deltaEnergy.isFinite else { return nil }
        let joules: Double
        switch unit.trimmingCharacters(in: .whitespaces) {
        case "mJ": joules = deltaEnergy / 1e3
        case "uJ": joules = deltaEnergy / 1e6
        case "nJ": joules = deltaEnergy / 1e9
        default: return nil
        }
        return joules / seconds
    }
}
