import SwiftUI

/// A titled box that holds one section of readings.
struct SectionCard<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.secondary)
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
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
