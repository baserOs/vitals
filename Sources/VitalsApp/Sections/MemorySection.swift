import SwiftUI
import VitalsCore

struct MemorySection: View {
    let snapshot: Snapshot

    var body: some View {
        SectionCard(title: "Memory", trailing: snapshot.memory.map { Format.percent($0.usedFraction) }) {
            if let memory = snapshot.memory {
                StackedBar(parts: parts(memory))
                HStack(spacing: 10) {
                    LegendDot(label: "App", tint: .blue)
                    LegendDot(label: "Wired", tint: .orange)
                    LegendDot(label: "Compressed", tint: .purple)
                    LegendDot(label: "Cached", tint: .gray)
                }
                ValueRow(label: "Used", value: "\(Format.bytes(memory.used)) of \(Format.bytes(memory.total))")
                ValueRow(label: "Pressure", value: pressureText(memory.pressure), tint: pressureTint(memory.pressure))
                ValueRow(label: "Swap used", value: Format.bytes(memory.swapUsed))
            } else {
                Unavailable()
            }
        }
    }

    private func parts(_ memory: MemoryReading) -> [StackedBar.Part] {
        let total = Double(max(1, memory.total))
        return [
            StackedBar.Part(id: 0, fraction: Double(memory.app) / total, tint: .blue),
            StackedBar.Part(id: 1, fraction: Double(memory.wired) / total, tint: .orange),
            StackedBar.Part(id: 2, fraction: Double(memory.compressed) / total, tint: .purple),
            StackedBar.Part(id: 3, fraction: Double(memory.cached) / total, tint: .gray),
        ]
    }

    private func pressureText(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: return "Normal"
        case .warning: return "Elevated"
        case .critical: return "Critical"
        }
    }

    private func pressureTint(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .primary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct LegendDot: View {
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
    }
}
