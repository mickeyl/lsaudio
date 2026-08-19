import CoreAudio
import Dispatch
import Foundation

/// Push-driven snapshots of coreaudiod clients. CoreAudio callbacks are coalesced on a private queue.
public final class AudioProcessMonitor: @unchecked Sendable {
    public typealias Handler = @Sendable ([AudioProcess], Date) -> Void

    private let queue = DispatchQueue(label: "de.vanille.lsaudio.monitor")
    private let handler: Handler
    private var currentObjectIDs: Set<AudioObjectID> = []
    private var pendingRefresh: DispatchWorkItem?
    private var started = false

    private lazy var listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.scheduleRefresh()
    }

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            var processListAddress = CoreAudioProperty.address(
                for: kAudioHardwarePropertyProcessObjectList
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &processListAddress,
                self.queue,
                self.listener
            )
            self.refresh()
        }
    }

    public func requestRefresh() {
        queue.async { [weak self] in self?.refresh() }
    }

    public func stop() {
        queue.async { [weak self] in self?.removeListeners() }
    }

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        queue.asyncAfter(deadline: .now() + .milliseconds(150), execute: work)
    }

    private func refresh() {
        guard started else { return }
        let snapshot = AudioProcess.snapshot()
        updateProcessListeners(for: snapshot)
        handler(snapshot, .now)
    }

    private func updateProcessListeners(for snapshot: [AudioProcess]) {
        let snapshotIDs = Set(snapshot.map(\.objectID))
        var outputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningOutput)
        var inputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningInput)

        for objectID in snapshotIDs.subtracting(currentObjectIDs) {
            AudioObjectAddPropertyListenerBlock(objectID, &outputAddress, queue, listener)
            AudioObjectAddPropertyListenerBlock(objectID, &inputAddress, queue, listener)
        }
        for objectID in currentObjectIDs.subtracting(snapshotIDs) {
            AudioObjectRemovePropertyListenerBlock(objectID, &outputAddress, queue, listener)
            AudioObjectRemovePropertyListenerBlock(objectID, &inputAddress, queue, listener)
        }
        currentObjectIDs = snapshotIDs
    }

    private func removeListeners() {
        guard started else { return }
        pendingRefresh?.cancel()
        var processListAddress = CoreAudioProperty.address(for: kAudioHardwarePropertyProcessObjectList)
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &processListAddress,
            queue,
            listener
        )
        var outputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningOutput)
        var inputAddress = CoreAudioProperty.address(for: kAudioProcessPropertyIsRunningInput)
        for objectID in currentObjectIDs {
            AudioObjectRemovePropertyListenerBlock(objectID, &outputAddress, queue, listener)
            AudioObjectRemovePropertyListenerBlock(objectID, &inputAddress, queue, listener)
        }
        currentObjectIDs.removeAll()
        started = false
    }
}
