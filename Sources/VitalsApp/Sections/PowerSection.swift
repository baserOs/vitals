import SwiftUI
import VitalsCore

struct PowerSection: View {
    let snapshot: Snapshot
    let limits: MachineLimits

    var body: some View {
        SectionCard(title: "Power", icon: "bolt.fill", tint: .orange,
                    trailing: snapshot.power?.systemWatts.map { Format.watts($0) }) {
            if let power = snapshot.power {
                if let system = power.systemWatts {
                    UsageBar(fraction: system / limits.systemWatts, tint: .orange)
                }
                ValueRow(label: "Whole system", value: Format.watts(power.systemWatts))
                ValueRow(label: "CPU", value: Format.watts(power.cpuWatts))
                ValueRow(label: "GPU", value: Format.watts(power.gpuWatts))
                ValueRow(label: "From adapter", value: power.adapterWatts.map { Format.watts($0) } ?? "on battery")
            } else {
                Unavailable()
            }
        }
    }
}
