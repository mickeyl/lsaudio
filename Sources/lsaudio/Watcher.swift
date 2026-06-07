import CoreAudio
import Dispatch
import Foundation

/// Event-driven live view: listens for coreaudiod process registrations and
/// per-process running-state changes, then redraws (TTY) or emits change
/// events (piped / --plain).
final class Watcher {
    private let all: Bool
    private let pattern: String?
    private let plainEvents: Bool
    private let style: OutputStyle
    private let queue = DispatchQueue(label: "lsaudio.watch")

    private var current: [pid_t: AudioProcess] = [:]
    private var listenedObjects: Set<AudioObjectID> = []
    private var pendingRefresh: DispatchWorkItem?
    private var signalSource: DispatchSourceSignal?

    private lazy var listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.scheduleRefresh()
    }

    init(all: Bool, pattern: String?, plainEvents: Bool, style: OutputStyle) {
        self.all = all
        self.pattern = pattern
        self.plainEvents = plainEvents
        self.style = style
    }

    func run() -> Never {
        installSignalHandler()
        var address = CoreAudioProperty.address(for: kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
        if !plainEvents {
            print("\u{1B}[?25l", terminator: "")
        }
        queue.async { self.refresh(initial: true) }
        dispatchMain()
    }

    // Listener callbacks arrive on our serial queue, so all state below is queue-confined.

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh(initial: false) }
        pendingRefresh = work
        // CoreAudio fires bursts of property changes; coalesce them into one redraw.
        queue.asyncAfter(deadline: .now() + .milliseconds(150), execute: work)
    }

    private func refresh(initial: Bool) {
        let snapshot = AudioProcess.snapshot()
        updateProcessListeners(for: snapshot)

        let selected = List.selectedProcesses(all: all, pattern: pattern)
        let selectedByPID = Dictionary(selected.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

        if plainEvents {
            emitEvents(new: selectedByPID, initial: initial)
        } else {
            redraw(selected)
        }
        current = selectedByPID
    }

    private func updateProcessListeners(for snapshot: [AudioProcess]) {
        let snapshotIDs = Set(snapshot.map(\.objectID))
        var outputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningOutput)
        var inputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningInput)

        for objectID in snapshotIDs.subtracting(listenedObjects) {
            AudioObjectAddPropertyListenerBlock(objectID, &outputAddress, queue, listener)
            AudioObjectAddPropertyListenerBlock(objectID, &inputAddress, queue, listener)
        }
        for objectID in listenedObjects.subtracting(snapshotIDs) {
            AudioObjectRemovePropertyListenerBlock(objectID, &outputAddress, queue, listener)
            AudioObjectRemovePropertyListenerBlock(objectID, &inputAddress, queue, listener)
        }
        listenedObjects = snapshotIDs
    }

    private func redraw(_ processes: [AudioProcess]) {
        var screen = "\u{1B}[2J\u{1B}[H"
        screen += style.dimmed("lsaudio — watching audio activity, Ctrl-C to stop") + "\n\n"
        screen += processes.isEmpty
            ? "No processes are currently playing or recording audio."
            : ProcessRenderer.table(for: processes, style: style)
        print(screen)
        fflush(stdout)
    }

    private func emitEvents(new: [pid_t: AudioProcess], initial: Bool) {
        var lines: [String] = []

        for process in new.values where process.isActive {
            let previous = current[process.pid]
            if initial {
                lines.append(eventLine("present", process))
            } else if previous?.isActive != true {
                lines.append(eventLine("start", process))
            } else if previous?.isRunningOutput != process.isRunningOutput
                || previous?.isRunningInput != process.isRunningInput {
                lines.append(eventLine("change", process))
            }
        }
        for process in current.values where process.isActive && new[process.pid]?.isActive != true {
            lines.append(eventLine("stop", process))
        }

        guard !lines.isEmpty else { return }
        print(lines.sorted().joined(separator: "\n"))
        fflush(stdout)
    }

    private func eventLine(_ action: String, _ process: AudioProcess) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let channels = switch (process.isRunningOutput, process.isRunningInput) {
            case (true, true): "output+input"
            case (true, false): "output"
            case (false, true): "input"
            case (false, false): "none"
        }
        return [timestamp, action, String(process.pid), process.name, process.bundleID ?? "-", channels]
            .joined(separator: "\t")
    }

    private func installSignalHandler() {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler { [plainEvents] in
            if !plainEvents {
                print("\u{1B}[?25h", terminator: "")
                fflush(stdout)
            }
            exit(130)
        }
        source.resume()
        signalSource = source
    }
}
