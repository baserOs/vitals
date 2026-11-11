import SwiftUI
import VitalisCore

/// How the cards are drawn: Liquid Glass in the menu bar popover, a plain
/// soft fill in the dashboard.
enum CardStyle {
    case glass
    case soft
}

private struct CardStyleKey: EnvironmentKey {
    static let defaultValue = CardStyle.soft
}

extension EnvironmentValues {
    var cardStyle: CardStyle {
        get { self[CardStyleKey.self] }
        set { self[CardStyleKey.self] = newValue }
    }
}

/// Corner radii. Everything uses continuous corners.
enum Curve {
    static let glassCard: CGFloat = 20
    static let softCard: CGFloat = 14
    static let tile: CGFloat = 12
}

extension View {
    /// The background of a card, following the card style around it.
    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    /// The background of a small tile inside a card.
    func tileSurface() -> some View {
        background(Color.primary.opacity(0.06),
                   in: RoundedRectangle(cornerRadius: Curve.tile, style: .continuous))
    }
}

struct CardSurface: ViewModifier {
    @Environment(\.cardStyle) private var style

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .glass:
            content.modifier(GlassSurface(radius: Curve.glassCard))
        case .soft:
            content.background(Color.primary.opacity(0.05),
                               in: RoundedRectangle(cornerRadius: Curve.softCard, style: .continuous))
        }
    }
}

/// Liquid Glass where the system has it, a translucent material before
/// that. The glass sits behind the content as its own layer, so thinning
/// it out never fades the text on top.
struct GlassSurface: ViewModifier {
    let radius: CGFloat
    @AppStorage(SettingsKey.popoverTransparency) private var transparency = SettingsDefault.popoverTransparency

    func body(content: Content) -> some View {
        content.background {
            GlassLayer(shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .opacity(1 - SettingsDefault.clampedTransparency(transparency))
        }
    }
}

struct GlassLayer: View {
    let shape: RoundedRectangle

    @ViewBuilder
    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            material
        }
        #else
        material
        #endif
    }

    private var material: some View {
        shape.fill(.regularMaterial)
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}

/// A capsule button: glass where the system has it.
struct PillButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
        #else
        content.buttonStyle(.bordered).buttonBorderShape(.capsule)
        #endif
    }
}

/// A symbol in a soft round badge, shown beside a card title.
struct IconBadge: View {
    let systemName: String
    var tint: Color = .accentColor

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 22, height: 22)
            .background(tint.opacity(0.18), in: Circle())
    }
}

/// A value with its name above and a few words below saying what it is.
struct StatTile: View {
    let title: String
    let value: String
    let hint: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(hint)
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.75))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tileSurface()
    }
}
