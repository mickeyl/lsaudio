import LSAudioCore
import SwiftUI

struct ProcessInspector: View {
    let process: AudioProcess
    let onSignal: () -> Void

    var body: some View {
        Form {
            Section(R.L.Inspector_IDENTITY) {
                HStack(spacing: 10) {
                    ProcessIcon(process: process, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(process.name)
                            .font(.headline)
                        Text("PID \(process.pid)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(R.L.Inspector_BUNDLE_ID) {
                    Text(process.bundleID ?? "—")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                LabeledContent(R.L.Inspector_EXECUTABLE) {
                    Text(process.executablePath ?? "—")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section(R.L.Inspector_ACTIVITY) {
                ActivityBadges(process: process)
            }

            Section(R.L.Inspector_AUDIO_DEVICES) {
                if process.deviceNames.isEmpty {
                    Text(R.L.Inspector_NO_DEVICES)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(process.deviceNames, id: \.self) { device in
                        Label(device, systemImage: "hifispeaker")
                    }
                }
            }

            Section {
                Button(R.L.Signal_ACTION, role: .destructive, action: onSignal)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }
}
