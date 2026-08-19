import Foundation
import LSAudioCore
import Observation

enum AppSection: String, CaseIterable, Identifiable {
    case processes
    case events

    var id: Self { self }
}

enum MenuAudioScope: String, CaseIterable, Identifiable {
    case output
    case input

    var id: Self { self }
}

enum ProcessSortOrder: String, CaseIterable, Identifiable {
    case activity
    case alphabetical
    case pid
    case device

    var id: Self { self }
}

@MainActor
@Observable
final class AppModel {
    private(set) var processes: [AudioProcess] = []
    private(set) var events: [AudioActivityEvent] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = true
    var errorMessage: String?
    var statusMessage: String?
    var searchText = ""
    var selectedSection: AppSection = .processes
    var selectedPID: pid_t?
    var menuScope: MenuAudioScope = .output
    var showIdle: Bool {
        didSet { UserDefaults.standard.set(showIdle, forKey: Self.showIdleKey) }
    }
    var showPaths: Bool {
        didSet { UserDefaults.standard.set(showPaths, forKey: Self.showPathsKey) }
    }
    var sortOrder: ProcessSortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey) }
    }
    var confirmsQuickTermination: Bool {
        didSet {
            UserDefaults.standard.set(
                confirmsQuickTermination,
                forKey: Self.confirmsQuickTerminationKey
            )
        }
    }

    @ObservationIgnored private var monitor: AudioProcessMonitor?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var previousByPID: [pid_t: AudioProcess] = [:]

    init() {
        showIdle = UserDefaults.standard.bool(forKey: Self.showIdleKey)
        showPaths = UserDefaults.standard.bool(forKey: Self.showPathsKey)
        sortOrder = UserDefaults.standard.string(forKey: Self.sortOrderKey)
            .flatMap(ProcessSortOrder.init(rawValue:)) ?? .activity
        confirmsQuickTermination = UserDefaults.standard.object(
            forKey: Self.confirmsQuickTerminationKey
        ) == nil || UserDefaults.standard.bool(forKey: Self.confirmsQuickTerminationKey)
    }

    var activeProcesses: [AudioProcess] { processes.filter(\.isActive) }
    var outputProcesses: [AudioProcess] { processes.filter(\.isRunningOutput) }
    var inputProcesses: [AudioProcess] { processes.filter(\.isRunningInput) }
    var outputCount: Int { outputProcesses.count }
    var inputCount: Int { inputProcesses.count }

    var visibleProcesses: [AudioProcess] {
        let activityFiltered = showIdle ? processes : activeProcesses
        let searchFiltered = activityFiltered.filter(matchesSearch)
        return sorted(searchFiltered)
    }

    var menuProcesses: [AudioProcess] {
        switch menuScope {
        case .output: sorted(outputProcesses)
        case .input: sorted(inputProcesses)
        }
    }

    var selectedProcess: AudioProcess? {
        guard let selectedPID else { return nil }
        return processes.first { $0.pid == selectedPID }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        isLoading = true
        let monitor = AudioProcessMonitor { [weak self] snapshot, capturedAt in
            Task { @MainActor in
                self?.receive(snapshot, capturedAt: capturedAt)
            }
        }
        self.monitor = monitor
        monitor.start()
    }

    func refresh() {
        isLoading = true
        monitor?.requestRefresh()
    }

    func clearEvents() {
        events.removeAll()
    }

    func matches(target: String?, includeIdle: Bool) -> [AudioProcess] {
        AudioProcessQuery.matches(
            from: processes,
            target: target?.isEmpty == true ? nil : target,
            includeIdle: includeIdle
        )
    }

    func showSignalResult(_ message: String) {
        statusMessage = message
    }

    func sendSignal(
        _ signal: AudioSignal,
        to targets: [AudioProcess],
        authorizeIfNeeded: Bool,
        reportsSuccess: Bool = true
    ) async {
        let result = await ProcessSignaler.shared.send(
            signal,
            to: targets,
            authorizeIfNeeded: authorizeIfNeeded
        )
        if !result.permissionDenied.isEmpty {
            let names = result.permissionDenied
                .map { "\($0.name) (PID \($0.pid))" }
                .joined(separator: ", ")
            errorMessage = R.L.Signal_PERMISSION_DENIED(names)
        } else if !result.failures.isEmpty {
            errorMessage = R.L.Signal_FAILED(result.failures.joined(separator: "\n"))
        } else if reportsSuccess {
            let signalLabel = signal.name.isEmpty ? "signal \(signal.number)" : signal.label
            statusMessage = result.deliveredCount == 1
                ? R.L.Signal_SENT_ONE(signalLabel)
                : R.L.Signal_SENT(signalLabel, result.deliveredCount)
        }
        refresh()
    }

    private func receive(_ snapshot: [AudioProcess], capturedAt: Date) {
        appendEvents(snapshot: snapshot, capturedAt: capturedAt)
        processes = snapshot
        previousByPID = Dictionary(snapshot.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        lastUpdated = capturedAt
        isLoading = false
        errorMessage = nil
        if let selectedPID, !snapshot.contains(where: { $0.pid == selectedPID }) {
            self.selectedPID = nil
        }
    }

    private func appendEvents(snapshot: [AudioProcess], capturedAt: Date) {
        let next = Dictionary(snapshot.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var changes: [AudioActivityEvent] = []

        if lastUpdated == nil {
            changes = snapshot.filter(\.isActive).map {
                AudioActivityEvent(action: .present, process: $0, timestamp: capturedAt)
            }
        } else {
            for process in snapshot where process.isActive {
                guard let previous = previousByPID[process.pid] else {
                    changes.append(AudioActivityEvent(action: .start, process: process, timestamp: capturedAt))
                    continue
                }
                if !previous.isActive {
                    changes.append(AudioActivityEvent(action: .start, process: process, timestamp: capturedAt))
                } else if previous.isRunningOutput != process.isRunningOutput
                            || previous.isRunningInput != process.isRunningInput {
                    changes.append(AudioActivityEvent(action: .change, process: process, timestamp: capturedAt))
                }
            }
            for previous in previousByPID.values where previous.isActive {
                if next[previous.pid]?.isActive != true {
                    changes.append(AudioActivityEvent(action: .stop, process: previous, timestamp: capturedAt))
                }
            }
        }

        changes.sort {
            let nameOrder = $0.process.name.localizedStandardCompare($1.process.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.process.pid < $1.process.pid
        }
        events.insert(contentsOf: changes, at: 0)
        if events.count > 500 { events.removeLast(events.count - 500) }
    }

    private func matchesSearch(_ process: AudioProcess) -> Bool {
        guard !searchText.isEmpty else { return true }
        let needle = searchText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let values = [
            process.name,
            process.bundleID ?? "",
            String(process.pid),
            process.executablePath ?? "",
        ] + process.deviceNames
        return values.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }

    private func sorted(_ source: [AudioProcess]) -> [AudioProcess] {
        source.sorted { lhs, rhs in
            switch sortOrder {
            case .activity:
                let lhsRank = activityRank(lhs)
                let rhsRank = activityRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case .alphabetical:
                break
            case .pid:
                if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
            case .device:
                let lhsDevice = lhs.deviceNames.first ?? ""
                let rhsDevice = rhs.deviceNames.first ?? ""
                let deviceOrder = lhsDevice.localizedStandardCompare(rhsDevice)
                if deviceOrder != .orderedSame { return deviceOrder == .orderedAscending }
            }
            let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.pid < rhs.pid
        }
    }

    private func activityRank(_ process: AudioProcess) -> Int {
        switch (process.isRunningOutput, process.isRunningInput) {
        case (true, true): 0
        case (true, false): 1
        case (false, true): 2
        case (false, false): 3
        }
    }

    private static let showIdleKey = "showIdleAudioClients"
    private static let showPathsKey = "showExecutablePaths"
    private static let sortOrderKey = "processSortOrder"
    private static let confirmsQuickTerminationKey = "confirmsQuickTermination"
}
