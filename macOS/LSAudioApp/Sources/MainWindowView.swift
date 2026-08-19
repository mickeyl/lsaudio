import AppKit
import LSAudioCore
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSignalSheet = false
    @State private var signalInitialTarget = ""
    @State private var isExporting = false
    @State private var exportDocument = AudioDataDocument()
    @State private var exportType: UTType = .json
    @State private var exportFilename = "lsaudio.json"

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(AppSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 230)
        } detail: {
            sectionContent
                .navigationTitle(model.selectedSection.title)
                .searchable(text: $model.searchText, prompt: R.L.Search_PROMPT)
                .toolbar { toolbar }
        }
        .frame(minWidth: 900, minHeight: 540)
        .inspector(isPresented: inspectorPresented) {
            if let process = model.selectedProcess {
                ProcessInspector(process: process) {
                    beginSignal(target: String(process.pid))
                }
                .inspectorColumnWidth(min: 280, ideal: 330, max: 400)
            }
        }
        .sheet(isPresented: $showsSignalSheet) {
            SignalActionSheet(initialTarget: signalInitialTarget)
                .environment(model)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportFilename
        ) { _ in }
        .alert(R.L.Error_TITLE, isPresented: errorPresented) {
            Button(R.L.Error_DISMISS) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(R.L.App_NAME, isPresented: statusPresented) {
            Button(R.L.Error_DISMISS) { model.statusMessage = nil }
        } message: {
            Text(model.statusMessage ?? "")
        }
        .onAppear { model.start() }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch model.selectedSection {
        case .processes:
            ProcessTable(processes: model.visibleProcesses, selection: selection, showPaths: model.showPaths)
        case .events:
            EventsTable(events: model.events, selection: selection)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: showIdle) {
                Label(R.L.Common_SHOW_IDLE, systemImage: "pause.circle")
            }
            .toggleStyle(.button)
            .help(R.L.Common_SHOW_IDLE)
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: showPaths) {
                Label(R.L.Common_SHOW_PATHS, systemImage: "terminal")
            }
            .toggleStyle(.button)
            .help(R.L.Common_SHOW_PATHS)
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
            Button { model.refresh() } label: {
                Label(R.L.Common_REFRESH, systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .help(R.L.Common_REFRESH)
        }

        if model.selectedSection == .events {
            ToolbarItem(placement: .automatic) {
                Button { model.clearEvents() } label: {
                    Label(R.L.Common_CLEAR, systemImage: "trash")
                }
                .disabled(model.events.isEmpty)
                .help(R.L.Common_CLEAR)
            }
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
            Menu {
                Button(R.L.Signal_ACTION) {
                    beginSignal(target: model.selectedPID.map(String.init) ?? "")
                }
                Button(R.L.Signal_STOP_ALL, role: .destructive) {
                    beginSignal(target: "")
                }
            } label: {
                Label(R.L.Signal_ACTION, systemImage: "waveform.slash")
            }
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                exportMenuItems(copy: true)
                Divider()
                exportMenuItems(copy: false)
            } label: {
                Label(R.L.Common_EXPORT, systemImage: "square.and.arrow.up")
            }
        }
    }

    @ViewBuilder
    private func exportMenuItems(copy: Bool) -> some View {
        if model.selectedSection == .events {
            Button(copy ? R.L.Export_COPY_EVENTS : R.L.Export_EVENTS) {
                copy ? copyEvents() : beginEventsExport()
            }
        } else {
            Button(copy ? R.L.Export_COPY_JSON : R.L.Export_JSON) {
                copy ? copyProcesses(.json) : beginProcessExport(.json)
            }
            Button(copy ? R.L.Export_COPY_PLAIN : R.L.Export_PLAIN) {
                copy ? copyProcesses(.plain) : beginProcessExport(.plain)
            }
        }
    }

    private var selection: Binding<pid_t?> {
        Binding(get: { model.selectedPID }, set: { model.selectedPID = $0 })
    }

    private var showIdle: Binding<Bool> {
        Binding(get: { model.showIdle }, set: { model.showIdle = $0 })
    }

    private var showPaths: Binding<Bool> {
        Binding(get: { model.showPaths }, set: { model.showPaths = $0 })
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { model.selectedProcess != nil },
            set: { if !$0 { model.selectedPID = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var statusPresented: Binding<Bool> {
        Binding(
            get: { model.statusMessage != nil },
            set: { if !$0 { model.statusMessage = nil } }
        )
    }

    private func beginSignal(target: String) {
        signalInitialTarget = target
        showsSignalSheet = true
    }

    private func processData(_ format: AudioExportFormat) -> Data? {
        let text: String?
        switch format {
        case .json:
            text = try? AudioProcessExport.json(model.visibleProcesses)
        case .plain:
            text = AudioProcessExport.plain(model.visibleProcesses, includePaths: model.showPaths)
        }
        return text?.data(using: .utf8)
    }

    private func eventsData() -> Data {
        model.events.reversed().map(\.plainLine).joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func copyProcesses(_ format: AudioExportFormat) {
        guard let data = processData(format), let text = String(data: data, encoding: .utf8) else { return }
        copy(text)
    }

    private func beginProcessExport(_ format: AudioExportFormat) {
        guard let data = processData(format) else { return }
        exportDocument = AudioDataDocument(data: data)
        exportType = format.contentType
        exportFilename = "lsaudio.\(format.filenameExtension)"
        isExporting = true
    }

    private func copyEvents() {
        copy(String(data: eventsData(), encoding: .utf8) ?? "")
    }

    private func beginEventsExport() {
        exportDocument = AudioDataDocument(data: eventsData())
        exportType = .tabSeparatedText
        exportFilename = "lsaudio-events.tsv"
        isExporting = true
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private extension AppSection {
    var title: String {
        switch self {
        case .processes: R.L.Sidebar_PROCESSES
        case .events: R.L.Sidebar_EVENTS
        }
    }

    var systemImage: String {
        switch self {
        case .processes: "waveform"
        case .events: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
}

private enum AudioExportFormat {
    case json
    case plain

    var contentType: UTType {
        switch self {
        case .json: .json
        case .plain: .tabSeparatedText
        }
    }

    var filenameExtension: String {
        switch self {
        case .json: "json"
        case .plain: "tsv"
        }
    }
}

private struct AudioDataDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .tabSeparatedText, .plainText]
    var data = Data()

    init() {}
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
