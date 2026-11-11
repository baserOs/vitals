import SwiftUI
import VitalisCore

struct CPUSection: View {
    let snapshot: Snapshot

    var body: some View {
        SectionCard(title: "CPU", icon: "cpu", tint: .blue, trailing: snapshot.cpu.map { Format.percent($0.total) }) {
            if let cpu = snapshot.cpu {
                CoreBars(cores: cpu.cores)
                if cpu.loadAverage.count == 3 {
                    Text("Load average  " + cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .monospacedDigit()
                }
            } else {
                Unavailable()
            }
        }
    }
}

/// One bar per core, efficiency cores on the left and performance cores on the right.
struct CoreBars: View {
    let cores: [CoreReading]

    var body: some View {
        let efficiency = cores.filter { $0.kind == .efficiency }
        let performance = cores.filter { $0.kind == .performance }
        HStack(alignment: .bottom, spacing: 14) {
            if !efficiency.isEmpty {
                CoreGroup(label: "Efficiency", cores: efficiency)
            }
            if !performance.isEmpty {
                CoreGroup(label: "Performance", cores: performance)
            }
        }
    }
}

struct CoreGroup: View {
    let label: String
    let cores: [CoreReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(cores) { core in
                    VerticalBar(fraction: core.usage, tint: Level.color(forLoad: core.usage))
                }
            }
            .frame(height: 36)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
    }
}
