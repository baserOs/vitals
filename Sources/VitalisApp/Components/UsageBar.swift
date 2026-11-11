import SwiftUI
import VitalisCore

/// Colours and clamping shared by the bars.
enum Level {
    /// Keeps a fraction inside 0...1 and turns anything that is not a number into 0.
    static func clamp(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0 }
        return min(1, max(0, fraction))
    }

    static func color(forLoad fraction: Double) -> Color {
        if fraction >= 0.85 { return .red }
        if fraction >= 0.6 { return .orange }
        return .green
    }

    static func color(forCelsius celsius: Double) -> Color {
        if celsius >= 90 { return .red }
        if celsius >= 75 { return .orange }
        return .primary
    }

    static func color(for level: HeatLevel) -> Color {
        switch level {
        case .normal: return .primary
        case .warm: return .orange
        case .hot: return .red
        }
    }
}

/// A horizontal bar filled from the left.
struct UsageBar: View {
    let fraction: Double
    var tint: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(tint)
                    .frame(width: Level.clamp(fraction) * proxy.size.width)
            }
        }
        .frame(height: height)
    }
}

/// A vertical bar filled from the bottom, used for one CPU core.
struct VerticalBar: View {
    let fraction: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint)
                    .frame(height: max(2, Level.clamp(fraction) * proxy.size.height))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(minWidth: 6, maxWidth: 14)
    }
}

/// A bar split into coloured parts, each a share of the whole.
struct StackedBar: View {
    struct Part: Identifiable {
        let id: Int
        let fraction: Double
        let tint: Color
    }

    let parts: [Part]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(parts) { part in
                    Rectangle()
                        .fill(part.tint)
                        .frame(width: Level.clamp(part.fraction) * proxy.size.width)
                }
                Spacer(minLength: 0)
            }
            .background(Color.primary.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
