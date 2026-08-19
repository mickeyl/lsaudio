import AppKit
import CoreAudio

/// One client process registered with coreaudiod, as exposed by the macOS process object API.
public struct AudioProcess: Identifiable, Hashable, Sendable {
    public var id: pid_t { pid }

    public let objectID: AudioObjectID
    public let pid: pid_t
    public let name: String
    public let bundleID: String?
    public let executablePath: String?
    public let isRunningOutput: Bool
    public let isRunningInput: Bool
    public let deviceNames: [String]

    public var isActive: Bool { isRunningOutput || isRunningInput }

    public var activityDescription: String {
        switch (isRunningOutput, isRunningInput) {
        case (true, true): "playing + recording"
        case (true, false): "playing"
        case (false, true): "recording"
        case (false, false): "idle"
        }
    }

    public var described: String {
        let origin = (bundleID ?? executablePath).map { " (\($0))" } ?? ""
        return "\(name)\(origin), PID \(pid) \u{2014} \(activityDescription)"
    }

    public init(
        objectID: AudioObjectID = 0,
        pid: pid_t,
        name: String,
        bundleID: String?,
        executablePath: String?,
        isRunningOutput: Bool,
        isRunningInput: Bool,
        deviceNames: [String]
    ) {
        self.objectID = objectID
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.executablePath = executablePath
        self.isRunningOutput = isRunningOutput
        self.isRunningInput = isRunningInput
        self.deviceNames = deviceNames
    }

    init?(objectID: AudioObjectID) {
        let pid = CoreAudioProperty.value(
            of: objectID,
            selector: kAudioProcessPropertyPID,
            default: pid_t(-1)
        )
        guard pid >= 0 else { return nil }

        let bundleID = CoreAudioProperty.string(of: objectID, selector: kAudioProcessPropertyBundleID)
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let executablePath = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0
            ? Self.string(from: pathBuffer)
            : nil
        let outputDeviceIDs = CoreAudioProperty.objectIDs(
            of: objectID,
            selector: kAudioProcessPropertyDevices,
            scope: kAudioObjectPropertyScopeOutput
        )
        let inputDeviceIDs = CoreAudioProperty.objectIDs(
            of: objectID,
            selector: kAudioProcessPropertyDevices,
            scope: kAudioObjectPropertyScopeInput
        )
        var seen = Set<AudioObjectID>()

        self.objectID = objectID
        self.pid = pid
        self.bundleID = (bundleID?.isEmpty ?? true) ? nil : bundleID
        self.executablePath = executablePath
        self.isRunningOutput = CoreAudioProperty.bool(
            of: objectID,
            selector: kAudioProcessPropertyIsRunningOutput
        )
        self.isRunningInput = CoreAudioProperty.bool(
            of: objectID,
            selector: kAudioProcessPropertyIsRunningInput
        )
        self.deviceNames = (outputDeviceIDs + inputDeviceIDs)
            .filter { seen.insert($0).inserted }
            .compactMap { CoreAudioProperty.string(of: $0, selector: kAudioObjectPropertyName) }
        self.name = Self.processName(for: pid, bundleID: self.bundleID, executablePath: executablePath)
    }

    /// Returns all coreaudiod clients with active processes first.
    public static func snapshot() -> [AudioProcess] {
        CoreAudioProperty.objectIDs(
            of: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList
        )
        .compactMap(AudioProcess.init(objectID:))
        .sorted(by: AudioProcessQuery.defaultOrder)
    }

    private static func processName(for pid: pid_t, bundleID: String?, executablePath: String?) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
            return name
        }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 {
            return string(from: buffer)
        }
        if let basename = executablePath?.split(separator: "/").last {
            return String(basename)
        }
        return bundleID ?? "?"
    }

    private static func string(from buffer: [CChar]) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

public enum AudioProcessQuery {
    public static func selected(
        from processes: [AudioProcess],
        includeIdle: Bool,
        pattern: String?
    ) -> [AudioProcess] {
        let activityFiltered = includeIdle ? processes : processes.filter(\.isActive)
        guard let pattern, !pattern.isEmpty else { return activityFiltered }
        return activityFiltered.filter { process in
            process.name.localizedCaseInsensitiveContains(pattern)
                || (process.bundleID?.localizedCaseInsensitiveContains(pattern) ?? false)
        }
    }

    public static func matches(
        from processes: [AudioProcess],
        target: String?,
        includeIdle: Bool,
        excludingPID: pid_t = getpid()
    ) -> [AudioProcess] {
        let candidates = selected(from: processes, includeIdle: includeIdle, pattern: nil)
        let matched: [AudioProcess]
        if let target, !target.isEmpty {
            if let pid = pid_t(target) {
                matched = candidates.filter { $0.pid == pid }
            } else {
                matched = candidates.filter {
                    $0.name.localizedCaseInsensitiveContains(target)
                        || ($0.bundleID?.localizedCaseInsensitiveContains(target) ?? false)
                }
            }
        } else {
            matched = candidates
        }
        return matched.filter { $0.pid != excludingPID }
    }

    static func defaultOrder(_ lhs: AudioProcess, _ rhs: AudioProcess) -> Bool {
        guard lhs.isActive == rhs.isActive else { return lhs.isActive }
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.pid < rhs.pid
    }
}
