import SwiftUI
import VitalisCore

/// The busiest apps. An app with several processes can be opened to show
/// them.
struct ProcessesSection: View {
    let snapshot: Snapshot
    /// Most apps to show.
    let limit: Int
    var sortByMemory = false
    @State private var opened: Set<String> = []

    var body: some View {
        SectionCard(title: "Top processes", icon: "list.bullet", tint: .gray,
                    trailing: sortByMemory ? "by memory" : "by processor") {
            let order: ProcessOrder = sortByMemory ? .memory : .cpu
            let groups = snapshot.apps.ranked(by: order, limit: limit)
            if groups.isEmpty {
                Text("Collecting…")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
            } else {
                ForEach(groups) { group in
                    ProcessGroupRow(group: group, order: order, isOpen: opened.contains(group.id)) {
                        if opened.contains(group.id) {
                            opened.remove(group.id)
                        } else {
                            opened.insert(group.id)
                        }
                    }
                }
            }
        }
    }
}

/// One app: its totals, and under them, when opened, its processes.
struct ProcessGroupRow: View {
    let group: ProcessGroup
    let order: ProcessOrder
    let isOpen: Bool
    let toggle: () -> Void

    private var canOpen: Bool { group.processCount > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(action: toggle) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .opacity(canOpen ? 1 : 0)
                        .frame(width: 10)
                    Text(group.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if canOpen {
                        Text("\(group.processCount)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    ProcessFiguresView(cpu: group.cpu, memoryBytes: group.memoryBytes, order: order)
                }
                .font(.callout)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Not `disabled`: that would grey out every app with one process.
            .allowsHitTesting(canOpen)
            .help(canOpen ? "Show the \(group.processCount) processes of \(group.name)" : group.name)

            if isOpen, canOpen {
                ForEach(group.members.ranked(by: order, limit: ProcessGroupRow.shownMembers)) { process in
                    HStack(spacing: 4) {
                        Text(process.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(Color.secondary)
                        Spacer(minLength: 8)
                        ProcessFiguresView(cpu: process.cpu, memoryBytes: process.memoryBytes, order: order)
                    }
                    .font(.caption)
                    .padding(.leading, 14)
                }
                let hidden = group.processCount - min(group.members.count, ProcessGroupRow.shownMembers)
                if hidden > 0 {
                    Text("and \(hidden) smaller ones")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .padding(.leading, 14)
                }
            }
        }
    }

    /// Most processes listed under an opened app.
    static let shownMembers = 6
}

/// The processor share and the memory of one row. The figure the list is
/// sorted by stands out; the other is dimmed.
struct ProcessFiguresView: View {
    let cpu: Double
    let memoryBytes: UInt64
    let order: ProcessOrder

    var body: some View {
        Text(Format.percent(cpu))
            .monospacedDigit()
            .foregroundStyle(order == .cpu ? Color.primary : Color.secondary)
            .frame(width: 52, alignment: .trailing)
        Text(Format.processMemory(memoryBytes))
            .monospacedDigit()
            .foregroundStyle(order == .memory ? Color.primary : Color.secondary)
            .frame(width: 76, alignment: .trailing)
    }
}
