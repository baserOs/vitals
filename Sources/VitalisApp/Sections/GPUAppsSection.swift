import SwiftUI
import VitalisCore

/// The apps using the GPU most, as shares of the GPU's total use.
struct GPUAppsSection: View {
    let snapshot: Snapshot

    var body: some View {
        SectionCard(title: "Top GPU processes", icon: "cube", tint: .indigo,
                    trailing: snapshot.gpu.map { Format.percent($0.usage) }) {
            if snapshot.gpuApps.isEmpty {
                Text(snapshot.gpu == nil ? "not available" : "Nothing is using the GPU right now")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(snapshot.gpuApps) { app in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(app.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(GPUAppsSection.share(app.usage))
                                .monospacedDigit()
                        }
                        .font(.callout)
                        UsageBar(fraction: app.usage, tint: .indigo, height: 4)
                    }
                }
            }
        }
    }

    /// Whole percent, with one decimal below 1% so a small user is not shown as 0%.
    static func share(_ usage: Double) -> String {
        usage < 0.01 ? String(format: "%.1f%%", usage * 100) : Format.percent(usage)
    }
}
