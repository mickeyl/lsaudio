import LSAudioCore
import SwiftUI

struct SignalActionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var target: String
    @State private var signalText = "TERM"
    @State private var includeIdle = false
    @State private var dryRun = false
    @State private var authorizeIfNeeded = true
    @State private var isSending = false

    init(initialTarget: String = "") {
        _target = State(initialValue: initialTarget)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(R.L.Signal_TARGET_PLACEHOLDER, text: $target)
                        .accessibilityLabel(R.L.Signal_TARGET)
                    TextField(R.L.Signal_SIGNAL, text: $signalText)
                        .monospaced()
                    Toggle(R.L.Signal_INCLUDE_IDLE, isOn: $includeIdle)
                        .disabled(target.isEmpty)
                    Toggle(R.L.Signal_DRY_RUN, isOn: $dryRun)
                    Toggle(R.L.Signal_AUTHORIZE, isOn: $authorizeIfNeeded)
                        .disabled(dryRun)
                }

                Section {
                    matchPreview
                } header: {
                    Text(matchCountTitle)
                } footer: {
                    if includeIdle && target.isEmpty {
                        Text(R.L.Signal_REFUSE_ALL_IDLE)
                    } else if let signalError {
                        Text(signalError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(R.L.Common_CANCEL, role: .cancel) { dismiss() }
                Spacer()
                Button(actionTitle, role: dryRun ? nil : .destructive) {
                    performAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(matches.isEmpty || parsedSignal == nil || isSending || invalidAllIdleSelection)
            }
            .padding(16)
        }
        .frame(width: 560, height: 560)
        .onChange(of: target) {
            if target.isEmpty { includeIdle = false }
        }
    }

    private var matchPreview: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(matches) { process in
                    ProcessSummaryRow(process: process)
                    if process.pid != matches.last?.pid { Divider() }
                }
            }
        }
        .frame(minHeight: 180, maxHeight: 260)
    }

    private var matches: [AudioProcess] {
        guard !invalidAllIdleSelection else { return [] }
        return model.matches(target: target, includeIdle: includeIdle)
    }

    private var parsedSignal: AudioSignal? {
        try? AudioSignal.parse(signalText)
    }

    private var signalError: String? {
        guard !signalText.isEmpty, parsedSignal == nil else { return nil }
        return R.L.Signal_FAILED(signalText)
    }

    private var invalidAllIdleSelection: Bool { includeIdle && target.isEmpty }

    private var matchCountTitle: String {
        switch matches.count {
        case 0: R.L.Signal_NO_MATCH
        case 1: R.L.Signal_MATCH_ONE
        default: R.L.Signal_MATCHES(matches.count)
        }
    }

    private var actionTitle: String {
        guard !dryRun else { return R.L.Signal_PREVIEW }
        return R.L.Signal_SEND(signalLabel)
    }

    private var signalLabel: String {
        guard let signal = parsedSignal else { return signalText }
        return signal.name.isEmpty ? "signal \(signal.number)" : signal.label
    }

    private func performAction() {
        guard let signal = parsedSignal else { return }
        let targets = matches
        if dryRun {
            model.showSignalResult(R.L.Signal_DRY_RESULT(signalLabel, targets.count))
            dismiss()
            return
        }

        isSending = true
        Task {
            await model.sendSignal(
                signal,
                to: targets,
                authorizeIfNeeded: authorizeIfNeeded
            )
            isSending = false
            dismiss()
        }
    }
}
