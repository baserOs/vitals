import SwiftUI
import VitalsCore

struct TemperaturesSection: View {
    let snapshot: Snapshot
    let unit: TemperatureUnit
    /// True shows one reading per spot. False lists every sensor.
    var summary = false

    var body: some View {
        SectionCard(title: "Temperatures", icon: "thermometer.medium", tint: .red,
                    trailing: snapshot.hottest.map { Format.temperature($0.celsius, unit: unit) }) {
            if summary {
                let highlights = TemperatureSummary.highlights(for: snapshot)
                if highlights.isEmpty {
                    Unavailable()
                } else {
                    TemperatureChips(highlights: highlights, unit: unit)
                }
            } else if snapshot.temperatures.isEmpty {
                Unavailable()
            } else {
                ForEach(SensorGroup.allCases, id: \.self) { group in
                    TemperatureGroup(group: group,
                                     readings: snapshot.temperatures.filter { $0.group == group },
                                     unit: unit)
                }
            }
        }
    }
}

/// One small tile per spot: symbol, temperature, name.
struct TemperatureChips: View {
    let highlights: [TemperatureHighlight]
    let unit: TemperatureUnit

    var body: some View {
        HStack(spacing: 6) {
            ForEach(highlights) { highlight in
                VStack(spacing: 3) {
                    Image(systemName: symbol(highlight.spot))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .frame(height: 16)
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
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
                .tileSurface()
            }
        }
    }

    private func symbol(_ spot: TemperatureSpot) -> String {
        switch spot {
        case .cpu: return "cpu"
        case .gpu: return "cube"
        case .battery: return "battery.75percent"
        case .ssd: return "internaldrive"
        case .surface: return "keyboard"
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
