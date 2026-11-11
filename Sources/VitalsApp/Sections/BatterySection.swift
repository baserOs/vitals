import SwiftUI
import VitalsCore

/// The battery at a glance: charge, what it is doing now, and three
/// figures with a few words each saying what they mean.
struct BatterySection: View {
    let snapshot: Snapshot
    let unit: TemperatureUnit

    var body: some View {
        SectionCard(title: "Battery", icon: icon, tint: .green,
                    trailing: snapshot.battery.map { "\(Int($0.percent.rounded()))%" }) {
            if let battery = snapshot.battery {
                UsageBar(fraction: battery.percent / 100, tint: battery.percent <= 15 ? .red : .green)
                Text(stateText(battery))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    StatTile(title: "Health",
                             value: battery.healthPercent.map { "\(Int($0.rounded()))%" } ?? Format.missing,
                             hint: "of original")
                    StatTile(title: "Cycles", value: "\(battery.cycleCount)", hint: "full charges")
                    StatTile(title: "Temp", value: Format.temperature(battery.celsius, unit: unit),
                             hint: "battery pack",
                             tint: battery.celsius.map { Level.color(for: TemperatureSpot.battery.level(celsius: $0)) }
                                 ?? .primary)
                }
            } else {
                Unavailable()
            }
        }
    }

    private var icon: String {
        guard let battery = snapshot.battery else { return "battery.0percent" }
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.percent <= 15 { return "battery.25percent" }
        return "battery.75percent"
    }

    /// One line: what the battery is doing and how fast.
    private func stateText(_ battery: BatteryReading) -> String {
        let watts = Format.watts(abs(battery.watts))
        let charger = battery.adapterWatts.map { String(format: " · %.0f W charger", $0) } ?? ""
        if battery.isCharging { return "Charging · \(watts) in" + charger }
        if battery.watts < -0.05 { return "On battery · using \(watts)" }
        if battery.isPluggedIn { return "Plugged in · not charging" + charger }
        return "Idle"
    }
}
