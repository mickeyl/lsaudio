import SwiftUI

struct EventsTable: View {
    let events: [AudioActivityEvent]
    @Binding var selection: pid_t?

    var body: some View {
        Table(events) {
            TableColumn(R.L.Table_TIME) { event in
                Text(event.timestamp, format: .dateTime.hour().minute().second())
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 95, max: 115)

            TableColumn(R.L.Table_EVENT) { event in
                EventBadge(action: event.action)
            }
            .width(min: 80, ideal: 95, max: 120)

            TableColumn(R.L.Table_PROCESS) { event in
                Button {
                    selection = event.process.pid
                } label: {
                    HStack(spacing: 8) {
                        ProcessIcon(process: event.process, size: 20)
                        Text(event.process.name)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .width(min: 180, ideal: 260)

            TableColumn(R.L.Table_PID) { event in
                Text(event.process.pid, format: .number.grouping(.never))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 75, max: 90)

            TableColumn(R.L.Table_BUNDLE_ID) { event in
                Text(event.process.bundleID ?? "—")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(event.process.bundleID == nil ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 180, ideal: 260)

            TableColumn(R.L.Table_DEVICES) { event in
                Text(event.process.deviceNames.isEmpty ? "—" : event.process.deviceNames.joined(separator: ", "))
                    .foregroundStyle(event.process.deviceNames.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 150, ideal: 230)
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView(
                    R.L.Sidebar_EVENTS,
                    systemImage: "clock",
                    description: Text(R.L.Status_MONITOR_NOTE)
                )
            }
        }
    }
}

private struct EventBadge: View {
    let action: AudioEventAction

    var body: some View {
        Text(action.title)
            .font(.caption.weight(.medium))
            .foregroundStyle(action.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(action.color.opacity(0.12), in: .capsule)
    }
}

private extension AudioEventAction {
    var title: String {
        switch self {
        case .present: R.L.Event_PRESENT
        case .start: R.L.Event_START
        case .change: R.L.Event_CHANGE
        case .stop: R.L.Event_STOP
        }
    }

    var color: Color {
        switch self {
        case .present: .secondary
        case .start: .green
        case .change: .blue
        case .stop: .orange
        }
    }
}
