import Foundation
import LSAudioCore
import Testing

@Suite("Audio process exports")
struct AudioProcessExportTests {
    private let process = AudioProcess(
        pid: 42,
        name: "afplay",
        bundleID: nil,
        executablePath: "/usr/bin/afplay",
        isRunningOutput: true,
        isRunningInput: false,
        deviceNames: ["Mac Speakers"]
    )

    @Test("Plain export preserves the CLI field order")
    func plain() {
        #expect(
            AudioProcessExport.plain([process])
                == "42\tafplay\t-\tyes\tno\tMac Speakers"
        )
        #expect(
            AudioProcessExport.plain([process], includePaths: true)
                == "42\tafplay\t-\tyes\tno\tMac Speakers\t/usr/bin/afplay"
        )
    }

    @Test("JSON export preserves the CLI keys and path")
    func json() throws {
        let data = Data(try AudioProcessExport.json([process]).utf8)
        let entries = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let entry = try #require(entries.first)
        #expect(entry["pid"] as? Int == 42)
        #expect(entry["name"] as? String == "afplay")
        #expect(entry["path"] as? String == "/usr/bin/afplay")
        #expect(entry["runningOutput"] as? Bool == true)
        #expect(entry["runningInput"] as? Bool == false)
        #expect(entry["devices"] as? [String] == ["Mac Speakers"])
    }
}
