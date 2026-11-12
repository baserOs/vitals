import SwiftUI
import VitalisCore

/// The temperatures that matter, one per spot. In the dashboard the full
/// sensor list sits folded underneath.
struct TemperaturesSection: View {
    let snapshot: Snapshot
    let unit: TemperatureUnit
    /// Whether the full sensor list can be unfolded below the summary.
    var listsEverySensor = false
    @State private var showsEverySensor = false

    var body: some View {
        SectionCard(title: "Temperatures", icon: "thermometer.medium", tint: .red,
                    trailing: snapshot.hottest.map { Format.temperature($0.celsius, unit: unit) }) {
            let highlights = TemperatureSummary.highlights(for: snapshot)
            if highlights.isEmpty {
                Unavailable()
            } else {
                TemperatureChips(highlights: highlights, unit: unit)
            }
            if listsEverySensor, !snapshot.temperatures.isEmpty {
                Button {
                    showsEverySensor.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .rotationEffect(.degrees(showsEverySensor ? 90 : 0))
                            .frame(width: 10)
                        Text(showsEverySensor ? "Hide the sensor list" : "All \(snapshot.temperatures.count) sensors")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showsEverySensor {
                    ForEach(SensorGroup.allCases, id: \.self) { group in
                        TemperatureGroup(group: group,
                                         readings: snapshot.temperatures.filter { $0.group == group },
                                         unit: unit)
                    }
                }
            }
        }
    }
}

/// One small tile per spot: temperature and name.
struct TemperatureChips: View {
    let highlights: [TemperatureHighlight]
    let unit: TemperatureUnit

    var body: some View {
        HStack(spacing: 6) {
            ForEach(highlights) { highlight in
                VStack(spacing: 2) {
                    // "≈" marks a spot with no sensor of its own.
                    Text((highlight.isEstimate ? "≈" : "") + Format.temperature(highlight.celsius, unit: unit))
                        .font(.callout)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(Level.color(for: highlight.level))
                    Text(highlight.spot.title)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 7)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
                .tileSurface()
            }
        }
    }
}

/// The sensors of one group, hottest first.
struct TemperatureGroup: View {
    let group: SensorGroup
    let readings: [TemperatureReading]
    let unit: TemperatureUnit

    var body: some View {
        if !readings.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                ForEach(readings) { reading in
                    ValueRow(label: reading.name,
                             value: Format.temperature(reading.celsius, unit: unit),
                             tint: Level.color(forCelsius: reading.celsius))
                }
            }
        }
    }
}
