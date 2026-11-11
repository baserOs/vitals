import SwiftUI
import VitalisCore

struct MemorySection: View {
    let snapshot: Snapshot
    /// True lists how many gigabytes each kind of memory takes.
    var detailed = false
    @Environment(\.cardStyle) private var style

    var body: some View {
        SectionCard(title: "Memory", icon: "memorychip", tint: .purple,
                    trailing: snapshot.memory.map { Format.percent($0.usedFraction) }) {
            if let memory = snapshot.memory {
                let palette = MemoryPalette(quiet: style == .glass)
                StackedBar(parts: parts(memory, palette))
                if detailed {
                    MemoryBreakdown(memory: memory, palette: palette)
                } else {
                    HStack(spacing: 10) {
                        LegendDot(label: "App", tint: palette.app)
                        LegendDot(label: "Wired", tint: palette.wired)
                        LegendDot(label: "Compressed", tint: palette.compressed)
                        LegendDot(label: "Cached", tint: palette.cached)
                    }
                }
                ValueRow(label: "Used", value: "\(Format.bytes(memory.used)) of \(Format.bytes(memory.total))")
                ValueRow(label: "Pressure", value: pressureText(memory.pressure), tint: pressureTint(memory.pressure))
                ValueRow(label: "Swap used", value: Format.bytes(memory.swapUsed))
            } else {
                Unavailable()
            }
        }
    }

    private func parts(_ memory: MemoryReading, _ palette: MemoryPalette) -> [StackedBar.Part] {
        let total = Double(max(1, memory.total))
        return [
            StackedBar.Part(id: 0, fraction: Double(memory.app) / total, tint: palette.app),
            StackedBar.Part(id: 1, fraction: Double(memory.wired) / total, tint: palette.wired),
            StackedBar.Part(id: 2, fraction: Double(memory.compressed) / total, tint: palette.compressed),
            StackedBar.Part(id: 3, fraction: Double(memory.cached) / total, tint: palette.cached),
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

/// The colours of the memory bar: vivid in the dashboard, toned down in
/// the popover.
struct MemoryPalette {
    let app: Color
    let wired: Color
    let compressed: Color
    let cached: Color

    init(quiet: Bool) {
        if quiet {
            app = Color(hue: 0.60, saturation: 0.30, brightness: 0.72)
            wired = Color(hue: 0.08, saturation: 0.30, brightness: 0.78)
            compressed = Color(hue: 0.76, saturation: 0.24, brightness: 0.74)
            cached = Color.gray.opacity(0.45)
        } else {
            app = .blue
            wired = .orange
            compressed = .purple
            cached = .gray
        }
    }
}

/// Each kind of memory with its size, two to a row.
struct MemoryBreakdown: View {
    let memory: MemoryReading
    let palette: MemoryPalette

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            row("App", memory.app, palette.app)
            row("Wired", memory.wired, palette.wired)
            row("Compressed", memory.compressed, palette.compressed)
            row("Cached", memory.cached, palette.cached)
            row("Free", memory.free, Color.primary.opacity(0.1))
        }
    }

    private func row(_ label: String, _ bytes: UInt64, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            LegendDot(label: label, tint: tint)
            Spacer(minLength: 4)
            Text(Format.bytes(bytes))
                .font(.caption)
                .monospacedDigit()
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
