import SwiftUI
import VitalsCore

struct TemperaturesSection: View {
    let snapshot: Snapshot
    let unit: TemperatureUnit
    /// Most rows to show per group. nil shows every sensor.
    var rowLimit: Int? = nil

    var body: some View {
        SectionCard(title: "Temperatures",
                    trailing: snapshot.hottest.map { Format.temperature($0.celsius, unit: unit) }) {
            if snapshot.temperatures.isEmpty {
                Unavailable()
            } else {
                ForEach(SensorGroup.allCases, id: \.self) { group in
                    TemperatureGroup(group: group,
                                     readings: snapshot.temperatures.filter { $0.group == group },
                                     unit: unit, rowLimit: rowLimit)
                }
            }
        }
    }
}

/// The sensors of one group, hottest first.
struct TemperatureGroup: View {
    let group: SensorGroup
    let readings: [TemperatureReading]
    let unit: TemperatureUnit
    let rowLimit: Int?

    var body: some View {
        if !readings.isEmpty {
            let shown = rowLimit.map { Array(readings.prefix($0)) } ?? readings
            VStack(alignment: .leading, spacing: 3) {
                Text(group.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                ForEach(shown) { reading in
                    ValueRow(label: reading.name,
                             value: Format.temperature(reading.celsius, unit: unit),
                             tint: Level.color(forCelsius: reading.celsius))
                }
                if shown.count < readings.count {
                    Text("+ \(readings.count - shown.count) more in the dashboard")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
