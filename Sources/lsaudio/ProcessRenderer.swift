import Foundation

/// Renders audio process snapshots as table, plain text, or JSON.
enum ProcessRenderer {

    static func table(for processes: [AudioProcess], style: OutputStyle) -> String {
        let headers = ["PID", "Process", "Bundle ID", "Out", "In", "Devices"]
        let rows = processes.map { process -> [Table.Cell] in
            let rowPrefix = process.isActive ? nil : style.dimPrefix
            return [
                Table.Cell(String(process.pid), ansiPrefix: rowPrefix),
                Table.Cell(process.name, ansiPrefix: rowPrefix),
                Table.Cell(process.bundleID ?? "—", ansiPrefix: rowPrefix),
                Table.Cell(process.isRunningOutput ? "▶" : "·",
                           ansiPrefix: process.isRunningOutput ? style.greenPrefix : style.dimPrefix),
                Table.Cell(process.isRunningInput ? "●" : "·",
                           ansiPrefix: process.isRunningInput ? style.redPrefix : style.dimPrefix),
                Table.Cell(process.deviceNames.joined(separator: ", "), ansiPrefix: rowPrefix),
            ]
        }
        return Table(headers: headers, rows: rows).rendered()
    }

    static func plain(for processes: [AudioProcess]) -> String {
        processes.map { process in
            [
                String(process.pid),
                process.name,
                process.bundleID ?? "-",
                process.isRunningOutput ? "yes" : "no",
                process.isRunningInput ? "yes" : "no",
                process.deviceNames.joined(separator: ","),
            ].joined(separator: "\t")
        }.joined(separator: "\n")
    }

    static func json(for processes: [AudioProcess]) throws -> String {
        let entries = processes.map { process in
            JSONProcess(
                pid: process.pid,
                name: process.name,
                bundleID: process.bundleID,
                runningOutput: process.isRunningOutput,
                runningInput: process.isRunningInput,
                devices: process.deviceNames
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(entries), as: UTF8.self)
    }

    private struct JSONProcess: Encodable {
        let pid: pid_t
        let name: String
        let bundleID: String?
        let runningOutput: Bool
        let runningInput: Bool
        let devices: [String]
    }
}
