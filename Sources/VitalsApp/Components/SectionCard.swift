import SwiftUI

/// A titled card that holds one section of readings.
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    var tint: Color = .accentColor
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                IconBadge(systemName: icon, tint: tint)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let trailing = trailing {
                    Text(trailing)
                        .font(.callout)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// A label on the left and a value on the right.
struct ValueRow: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.callout)
    }
}

/// Shown in place of a section's content when its source gave nothing.
struct Unavailable: View {
    var body: some View {
        Text("not available")
            .font(.callout)
            .foregroundStyle(Color.secondary)
    }
}
