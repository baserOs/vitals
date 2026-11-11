import Foundation

public enum HeatLevel: Sendable, Equatable {
    case normal
    case warm
    case hot
}

/// The few places whose temperature matters at a glance.
public enum TemperatureSpot: String, Sendable, CaseIterable, Identifiable {
    case cpu
    case gpu
    case battery
    case ssd
    /// The palm rest and keyboard: the part of the case that hands touch.
    case surface

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        case .ssd: return "SSD"
        case .surface: return "Palm rest"
        }
    }

    var group: SensorGroup {
        switch self {
        case .cpu: return .cpu
        case .gpu: return .gpu
        case .battery: return .battery
        case .ssd: return .ssd
        case .surface: return .surface
        }
    }

    /// Where "warm" and "hot" start, in Celsius. Chips run far hotter than
    /// a battery or a surface that is touched should.
    var thresholds: (warm: Double, hot: Double) {
        switch self {
        case .cpu, .gpu: return (75, 90)
        case .ssd: return (60, 70)
        case .battery: return (38, 45)
        case .surface: return (38, 44)
        }
    }

    public func level(celsius: Double) -> HeatLevel {
        let limits = thresholds
        if celsius >= limits.hot { return .hot }
        if celsius >= limits.warm { return .warm }
        return .normal
    }
}

/// One spot and its temperature.
public struct TemperatureHighlight: Sendable, Equatable, Identifiable {
    public let spot: TemperatureSpot
    public let celsius: Double
    /// True when the Mac has no sensor for this spot and a neighbouring
    /// one stands in for it.
    public let isEstimate: Bool

    public var id: String { spot.rawValue }
    public var level: HeatLevel { spot.level(celsius: celsius) }

    public init(spot: TemperatureSpot, celsius: Double, isEstimate: Bool = false) {
        self.spot = spot
        self.celsius = celsius
        self.isEstimate = isEstimate
    }
}

public enum TemperatureSummary {
    /// One reading per spot, the hottest sensor of each. A spot with no
    /// sensor is left out.
    public static func highlights(for snapshot: Snapshot) -> [TemperatureHighlight] {
        func hottest(_ group: SensorGroup) -> Double? {
            snapshot.temperatures.filter { $0.group == group }.map(\.celsius).max()
        }

        var result: [TemperatureHighlight] = []
        for spot in TemperatureSpot.allCases {
            switch spot {
            case .battery:
                if let celsius = batteryCelsius(for: snapshot) {
                    result.append(TemperatureHighlight(spot: spot, celsius: celsius))
                }
            case .surface:
                if let celsius = surface(in: snapshot.temperatures) {
                    result.append(TemperatureHighlight(spot: spot, celsius: celsius))
                } else if let celsius = batteryCelsius(for: snapshot) {
                    // The battery lies directly under the palm rest and trackpad.
                    result.append(TemperatureHighlight(spot: spot, celsius: celsius, isEstimate: true))
                }
            default:
                if let celsius = hottest(spot.group) {
                    result.append(TemperatureHighlight(spot: spot, celsius: celsius))
                }
            }
        }
        return result
    }

    /// The battery pack's temperature: its warmest sensor, or else what the
    /// battery controller reports. nil when this Mac gives neither.
    public static func batteryCelsius(for snapshot: Snapshot) -> Double? {
        snapshot.temperatures.filter { $0.group == .battery }.map(\.celsius).max() ?? snapshot.battery?.celsius
    }

    /// The skin sensor to trust. These sit inside the case, so they read
    /// warmer than the surface itself, and one of them ("Ts0P") sits near
    /// warm parts and reads about 50 °C on a Mac that is cool to the touch.
    /// "Ts1P" follows the palm rest; without it, the coolest one is the
    /// closest to what a hand feels.
    static func surface(in temperatures: [TemperatureReading]) -> Double? {
        let skin = temperatures.filter { $0.group == .surface }
        if let preferred = skin.first(where: { $0.key == "Ts1P" }) { return preferred.celsius }
        return skin.map(\.celsius).min()
    }
}
