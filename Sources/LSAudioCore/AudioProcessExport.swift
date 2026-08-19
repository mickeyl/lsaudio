import Foundation

public enum AudioProcessExport {
    public static func plain(_ processes: [AudioProcess], includePaths: Bool = false) -> String {
        processes.map { process in
            ([
                String(process.pid),
                process.name,
                process.bundleID ?? "-",
                process.isRunningOutput ? "yes" : "no",
                process.isRunningInput ? "yes" : "no",
                process.deviceNames.joined(separator: ","),
            ] + (includePaths ? [process.executablePath ?? "-"] : []))
                .joined(separator: "\t")
        }
        .joined(separator: "\n")
    }

    public static func json(_ processes: [AudioProcess]) throws -> String {
        let entries = processes.map(JSONProcess.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(entries), as: UTF8.self)
    }

    private struct JSONProcess: Encodable {
        let pid: pid_t
        let name: String
        let bundleID: String?
        let path: String?
        let runningOutput: Bool
        let runningInput: Bool
        let devices: [String]

        init(_ process: AudioProcess) {
            pid = process.pid
            name = process.name
            bundleID = process.bundleID
            path = process.executablePath
            runningOutput = process.isRunningOutput
            runningInput = process.isRunningInput
            devices = process.deviceNames
        }
    }
}
