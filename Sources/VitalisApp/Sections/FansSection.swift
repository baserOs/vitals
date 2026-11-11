import SwiftUI
import VitalisCore

/// Fan speeds, for reading only.
struct FansSection: View {
    let snapshot: Snapshot
    /// Whether to list each fan's speed range under its bar.
    var showsRange = true

    var body: some View {
        SectionCard(title: "Fans", icon: "fan", tint: .teal, trailing: snapshot.fastestFan.map { Format.rpm($0.rpm) }) {
            if snapshot.fans.isEmpty {
                Unavailable()
            } else {
                ForEach(snapshot.fans) { fan in
                    VStack(alignment: .leading, spacing: 4) {
                        ValueRow(label: snapshot.fans.count == 1 ? "Fan" : "Fan \(fan.id + 1)",
                                 value: fan.rpm < 1 ? "0 rpm (stopped)" : Format.rpm(fan.rpm))
                        UsageBar(fraction: fan.fraction)
                        if showsRange, fan.maxRPM > fan.minRPM {
                            Text("Range \(Format.rpm(fan.minRPM)) to \(Format.rpm(fan.maxRPM))")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }
    }
}
