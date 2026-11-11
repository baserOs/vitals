import SwiftUI
import VitalisCore

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
                        // The figure the list is sorted by stands out; the other is dimmed.
                        Text(Format.percent(process.cpu))
                            .monospacedDigit()
                            .foregroundStyle(sortByMemory ? Color.secondary : Color.primary)
                            .frame(width: 52, alignment: .trailing)
                        Text(Format.processMemory(process.memoryBytes))
                            .monospacedDigit()
                            .foregroundStyle(sortByMemory ? Color.primary : Color.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var sorted: [ProcessReading] {
        snapshot.processes.ranked(by: sortByMemory ? .memory : .cpu, limit: limit)
    }
}
