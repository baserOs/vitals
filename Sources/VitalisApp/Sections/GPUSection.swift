import SwiftUI
import VitalisCore

struct GPUSection: View {
    let snapshot: Snapshot

    var body: some View {
        SectionCard(title: "GPU", icon: "cube", tint: .indigo, trailing: snapshot.gpu.map { Format.percent($0.usage) }) {
            if let gpu = snapshot.gpu {
                UsageBar(fraction: gpu.usage, tint: Level.color(forLoad: gpu.usage))
            } else {
                Unavailable()
            }
        }
    }
}
