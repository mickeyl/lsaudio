import LSAudioCore
import Testing

@Suite("Audio process queries")
struct AudioProcessQueryTests {
    private let active = AudioProcess(
        pid: 100,
        name: "Safari Graphics and Media",
        bundleID: "com.apple.WebKit.GPU",
        executablePath: "/System/Safari",
        isRunningOutput: true,
        isRunningInput: false,
        deviceNames: ["Mac Speakers"]
    )
    private let idle = AudioProcess(
        pid: 200,
        name: "Music",
        bundleID: "com.apple.Music",
        executablePath: "/System/Music",
        isRunningOutput: false,
        isRunningInput: false,
        deviceNames: []
    )

    @Test("Default selection only includes active clients")
    func activeSelection() {
        #expect(AudioProcessQuery.selected(from: [active, idle], includeIdle: false, pattern: nil) == [active])
    }

    @Test("Pattern matches names and bundle identifiers")
    func patternSelection() {
        #expect(AudioProcessQuery.selected(from: [active, idle], includeIdle: true, pattern: "webkit") == [active])
        #expect(AudioProcessQuery.selected(from: [active, idle], includeIdle: true, pattern: "music") == [idle])
    }

    @Test("Kill target accepts a PID and excludes the caller")
    func targetMatching() {
        #expect(AudioProcessQuery.matches(from: [active, idle], target: "100", includeIdle: true, excludingPID: 999) == [active])
        #expect(AudioProcessQuery.matches(from: [active], target: nil, includeIdle: false, excludingPID: 100).isEmpty)
    }
}
