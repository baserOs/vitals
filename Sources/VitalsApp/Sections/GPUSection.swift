import SwiftUI
import VitalsCore

struct GPUSection: View {
    let snapshot: Snapshot

    var body: some View {
        SectionCard(title: "GPU", trailing: snapshot.gpu.map { Format.percent($0.usage) }) {
            if let gpu = snapshot.gpu {
                UsageBar(fraction: gpu.usage, tint: Level.color(forLoad: gpu.usage))
            } else {
                Unavailable()
            }
        }
    }
}
