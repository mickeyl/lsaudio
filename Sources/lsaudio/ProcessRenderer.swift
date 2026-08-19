import Foundation
import LSAudioCore

/// Renders audio process snapshots as table, plain text, or JSON.
enum ProcessRenderer {

    static func table(for processes: [AudioProcess], style: OutputStyle, paths: Bool = false) -> String {
        let headers = ["PID", "Process", "Bundle ID", "Out", "In", "Devices"] + (paths ? ["Path"] : [])
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
            ] + (paths ? [Table.Cell(process.executablePath ?? "—", ansiPrefix: rowPrefix)] : [])
        }
        return Table(headers: headers, rows: rows).rendered()
    }

    static func plain(for processes: [AudioProcess], paths: Bool = false) -> String {
        AudioProcessExport.plain(processes, includePaths: paths)
    }

    static func json(for processes: [AudioProcess]) throws -> String {
        try AudioProcessExport.json(processes)
    }
}
