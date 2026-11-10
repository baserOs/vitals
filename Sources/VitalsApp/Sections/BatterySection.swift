import SwiftUI
import VitalsCore

struct BatterySection: View {
    let snapshot: Snapshot
    let unit: TemperatureUnit

    var body: some View {
        SectionCard(title: "Battery", trailing: snapshot.battery.map { "\(Int($0.percent.rounded()))%" }) {
            if let battery = snapshot.battery {
                UsageBar(fraction: battery.percent / 100, tint: battery.percent <= 15 ? .red : .green)
                ValueRow(label: "State", value: stateText(battery))
                ValueRow(label: "Cycles", value: "\(battery.cycleCount)")
                ValueRow(label: "Health",
                         value: battery.healthPercent.map { "\(Int($0.rounded()))%" } ?? Format.missing)
                ValueRow(label: "Temperature", value: Format.temperature(battery.celsius, unit: unit))
            } else {
                Unavailable()
            }
        }
    }

    private func stateText(_ battery: BatteryReading) -> String {
        let watts = Format.watts(abs(battery.watts))
        if battery.isCharging { return "Charging at \(watts)" }
        if battery.watts < -0.05 { return "Discharging at \(watts)" }
        if battery.isPluggedIn { return "Plugged in, not charging" }
        return "Idle"
    }
}
