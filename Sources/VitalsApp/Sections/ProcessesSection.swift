import SwiftUI
import VitalsCore

struct ProcessesSection: View {
    let snapshot: Snapshot
    /// Most rows to show.
    let limit: Int
    var sortByMemory = false

    var body: some View {
        SectionCard(title: "Top processes", icon: "list.bullet", tint: .gray,
                    trailing: sortByMemory ? "by memory" : "by processor") {
            let rows = sorted
            if rows.isEmpty {
                Text("Collecting…")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(rows) { process in
                    HStack {
                        Text(process.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(Format.percent(process.cpu))
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                        Text(Format.bytes(process.memoryBytes))
                            .monospacedDigit()
                            .foregroundStyle(Color.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                    .font(.callout)
                }
                Text("Shows your own apps. macOS hides system processes from apps without administrator rights.")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sorted: [ProcessReading] {
        let ordered: [ProcessReading]
        if sortByMemory {
            ordered = snapshot.processes.sorted(by: { $0.memoryBytes > $1.memoryBytes })
        } else {
            ordered = snapshot.processes.sorted(by: { $0.cpu > $1.cpu })
        }
        return Array(ordered.prefix(limit))
    }
}
