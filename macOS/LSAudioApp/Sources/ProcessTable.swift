import LSAudioCore
import SwiftUI

struct ProcessTable: View {
    let processes: [AudioProcess]
    @Binding var selection: pid_t?
    let showPaths: Bool

    var body: some View {
        Table(processes, selection: $selection) {
            TableColumn(R.L.Table_PROCESS) { process in
                HStack(spacing: 8) {
                    ProcessIcon(process: process, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(process.name)
                            .lineLimit(1)
                        Text(process.localizedActivityDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 170, ideal: 230)

            TableColumn(R.L.Table_PID) { process in
                Text(process.pid, format: .number.grouping(.never))
                    .monospacedDigit()
            }
            .width(min: 60, ideal: 72, max: 90)
            .alignment(.numeric)

            TableColumn(R.L.Table_BUNDLE_ID) { process in
                Text(process.bundleID ?? "—")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(process.bundleID == nil ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 170, ideal: 240)

            TableColumn(R.L.Table_OUTPUT) { process in
                Image(systemName: process.isRunningOutput ? "speaker.wave.2.fill" : "minus")
                    .foregroundStyle(process.isRunningOutput ? LSAudioTheme.output : .secondary)
                    .accessibilityLabel(process.isRunningOutput ? R.L.Activity_PLAYING : R.L.Activity_IDLE)
            }
            .width(70)
            .alignment(.center)

            TableColumn(R.L.Table_INPUT) { process in
                Image(systemName: process.isRunningInput ? "mic.fill" : "minus")
                    .foregroundStyle(process.isRunningInput ? LSAudioTheme.input : .secondary)
                    .accessibilityLabel(process.isRunningInput ? R.L.Activity_RECORDING : R.L.Activity_IDLE)
            }
            .width(65)
            .alignment(.center)

            TableColumn(R.L.Table_DEVICES) { process in
                Text(process.deviceNames.isEmpty ? "—" : process.deviceNames.joined(separator: ", "))
                    .foregroundStyle(process.deviceNames.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }
            .width(min: 140, ideal: 210)

            if showPaths {
                TableColumn(R.L.Table_PATH) { process in
                    Text(process.executablePath ?? "—")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(process.executablePath == nil ? .secondary : .primary)
                        .lineLimit(1)
                }
                .width(min: 220, ideal: 360)
            }
        }
        .overlay {
            if processes.isEmpty {
                ContentUnavailableView(
                    R.L.Status_NO_RESULTS,
                    systemImage: "waveform.slash"
                )
            }
        }
    }
}
