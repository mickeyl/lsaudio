import AppKit
import CoreAudio

/// One client process registered with coreaudiod, as exposed by the macOS 14 process object API.
struct AudioProcess {
    let objectID: AudioObjectID
    let pid: pid_t
    let name: String
    let bundleID: String?
    let executablePath: String?
    let isRunningOutput: Bool
    let isRunningInput: Bool
    let deviceNames: [String]

    var isActive: Bool { isRunningOutput || isRunningInput }

    var activityDescription: String {
        switch (isRunningOutput, isRunningInput) {
            case (true, true): "playing + recording"
            case (true, false): "playing"
            case (false, true): "recording"
            case (false, false): "idle"
        }
    }

    init?(objectID: AudioObjectID) {
        let pid = CoreAudioProperty.value(of: objectID, selector: kAudioProcessPropertyPID, default: pid_t(-1))
        guard pid >= 0 else { return nil }

        let bundleID = CoreAudioProperty.string(of: objectID, selector: kAudioProcessPropertyBundleID)

        self.objectID = objectID
        self.pid = pid
        self.bundleID = (bundleID?.isEmpty ?? true) ? nil : bundleID
        // The executable path unmasks anonymous helpers, e.g. simulator daemons under /Library/Developer/CoreSimulator.
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let executablePath = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0
            ? String(cString: pathBuffer)
            : nil
        self.executablePath = executablePath
        self.isRunningOutput = CoreAudioProperty.bool(of: objectID, selector: kAudioProcessPropertyIsRunningOutput)
        self.isRunningInput = CoreAudioProperty.bool(of: objectID, selector: kAudioProcessPropertyIsRunningInput)
        // The scope selects the output vs. input device list, so query both and merge.
        let deviceIDs = CoreAudioProperty.objectIDs(of: objectID, selector: kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeOutput)
            + CoreAudioProperty.objectIDs(of: objectID, selector: kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeInput)
        var seen = Set<AudioObjectID>()
        self.deviceNames = deviceIDs
            .filter { seen.insert($0).inserted }
            .compactMap { CoreAudioProperty.string(of: $0, selector: kAudioObjectPropertyName) }
        self.name = Self.processName(for: pid, bundleID: self.bundleID, executablePath: executablePath)
    }

    /// All coreaudiod clients, active ones first.
    static func snapshot() -> [AudioProcess] {
        CoreAudioProperty.objectIDs(of: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyProcessObjectList)
            .compactMap(AudioProcess.init(objectID:))
            .sorted {
                guard $0.isActive == $1.isActive else { return $0.isActive }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func processName(for pid: pid_t, bundleID: String?, executablePath: String?) -> String {
        // NSRunningApplication yields the localized app name; plain daemons fall back to the kernel's
        // process name, and some system daemons only reveal themselves via their executable path.
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
            return name
        }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 {
            return String(cString: buffer)
        }
        if let basename = executablePath?.split(separator: "/").last {
            return String(basename)
        }
        return bundleID ?? "?"
    }
}
