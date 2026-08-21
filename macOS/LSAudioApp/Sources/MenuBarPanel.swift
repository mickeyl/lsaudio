import AppKit
import LSAudioCore
import SwiftUI

struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var showsSettings = false
    @State private var terminatingPIDs = Set<pid_t>()
    @State private var pendingTermination: AudioProcess?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if showsSettings {
                    MenuBarSettingsView()
                } else {
                    processSummary
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            actions
        }
        .frame(width: LSAudioMetrics.menuWidth, height: LSAudioMetrics.menuHeight)
        .onAppear {
            model.start()
            model.setMenuBarPanelVisible(true)
        }
        .onDisappear { model.setMenuBarPanelVisible(false) }
        .alert(R.L.Error_TITLE, isPresented: errorPresented) {
            Button(R.L.Error_DISMISS) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog(
            R.L.Signal_CONFIRM_TITLE,
            isPresented: terminationConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(R.L.Signal_CONFIRM_ACTION, role: .destructive) {
                guard let pendingProcess = pendingTermination else { return }
                pendingTermination = nil
                guard let currentProcess = model.processes.first(where: {
                    $0.pid == pendingProcess.pid && $0.objectID == pendingProcess.objectID
                }) else { return }
                terminate(currentProcess)
            }
            Button(R.L.Common_CANCEL, role: .cancel) {
                pendingTermination = nil
            }
        } message: {
            if let process = pendingTermination {
                Text(R.L.Signal_CONFIRM_MESSAGE(process.name, Int(process.pid)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(R.L.App_NAME)
                    .font(.headline)
                if model.isLoading {
                    Text(R.L.Status_LOADING)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let lastUpdated = model.lastUpdated {
                    Text(R.L.Status_LAST_UPDATED(lastUpdated.formatted(date: .omitted, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.isLoading)
            .accessibilityLabel(R.L.Common_REFRESH)
            .help(R.L.Common_REFRESH)
        }
        .padding(LSAudioMetrics.menuPadding)
    }

    private var processSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            scopeButtons

            if model.menuProcesses.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: model.menuScope == .output ? "speaker.slash" : "mic.slash",
                    description: Text(R.L.Status_MONITOR_NOTE)
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.menuProcesses) { process in
                            HStack(spacing: 8) {
                                Button {
                                    model.selectedPID = process.pid
                                    showProcessWindow()
                                } label: {
                                    ProcessSummaryRow(process: process)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                quickTerminateButton(process)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .contentMargins(.trailing, LSAudioMetrics.menuScrollTrailing, for: .scrollContent)
            }
        }
        .padding(LSAudioMetrics.menuPadding)
    }

    private var scopeButtons: some View {
        HStack(spacing: 8) {
            scopeButton(
                .output,
                title: R.L.Count_PLAYING(model.outputCount),
                systemImage: "speaker.wave.2.fill"
            )
            scopeButton(
                .input,
                title: R.L.Count_RECORDING(model.inputCount),
                systemImage: "mic.fill"
            )
        }
    }

    private func scopeButton(
        _ scope: MenuAudioScope,
        title: String,
        systemImage: String
    ) -> some View {
        Toggle(isOn: scopeSelection(scope)) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .toggleStyle(.button)
    }

    private func scopeSelection(_ scope: MenuAudioScope) -> Binding<Bool> {
        Binding(
            get: { model.menuScope == scope },
            set: { if $0 { model.menuScope = scope } }
        )
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { showProcessWindow() } label: {
                Label(R.L.Common_OPEN_WINDOW, systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Toggle(isOn: $showsSettings) {
                Label(R.L.Common_SETTINGS, systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .accessibilityLabel(R.L.Common_SETTINGS)
            .help(R.L.Common_SETTINGS)

            Button { NSApplication.shared.terminate(nil) } label: {
                Label(R.L.Common_QUIT, systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(R.L.Common_QUIT)
            .help(R.L.Common_QUIT)
        }
        .padding(LSAudioMetrics.menuPadding)
    }

    private var emptyTitle: String {
        model.menuScope == .output ? R.L.Status_NO_OUTPUT : R.L.Status_NO_INPUT
    }

    private func quickTerminateButton(_ process: AudioProcess) -> some View {
        let label = R.L.Signal_QUICK_TERMINATE(process.name)
        return Button(role: .destructive) {
            requestTermination(process)
        } label: {
            Group {
                if terminatingPIDs.contains(process.pid) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .frame(width: LSAudioMetrics.quickActionSize, height: LSAudioMetrics.quickActionSize)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(LSAudioTheme.destructive)
        .disabled(terminatingPIDs.contains(process.pid))
        .accessibilityLabel(label)
        .help(label)
    }

    private func requestTermination(_ process: AudioProcess) {
        if model.confirmsQuickTermination {
            pendingTermination = process
        } else {
            terminate(process)
        }
    }

    private func terminate(_ process: AudioProcess) {
        guard terminatingPIDs.insert(process.pid).inserted else { return }
        Task {
            await model.sendSignal(
                .term,
                to: [process],
                authorizeIfNeeded: true,
                reportsSuccess: false
            )
            terminatingPIDs.remove(process.pid)
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var terminationConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingTermination != nil },
            set: { if !$0 { pendingTermination = nil } }
        )
    }

    private func showProcessWindow() {
        openWindow(id: "processes")
        dismiss()
        NSApplication.shared.activate()
        Task { @MainActor in
            await Task.yield()
            NSApplication.shared.activate()
        }
    }
}
