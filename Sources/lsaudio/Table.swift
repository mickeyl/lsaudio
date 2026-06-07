/// Unicode box-drawing table in the same visual style as lsusd.
struct Table {
    struct Cell {
        let text: String
        let ansiPrefix: String?

        init(_ text: String, ansiPrefix: String? = nil) {
            self.text = text
            self.ansiPrefix = ansiPrefix
        }
    }

    let headers: [String]
    let rows: [[Cell]]

    func rendered() -> String {
        var widths = headers.map(\.count)
        for row in rows {
            for (index, cell) in row.enumerated() {
                widths[index] = max(widths[index], cell.text.count)
            }
        }

        func line(_ left: String, _ mid: String, _ right: String) -> String {
            left + widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: mid) + right
        }

        func dataRow(_ cells: [String]) -> String {
            "│" + cells.joined(separator: "│") + "│"
        }

        func centered(_ text: String, width: Int) -> String {
            let total = width - text.count
            let left = total / 2
            return String(repeating: " ", count: left) + text + String(repeating: " ", count: total - left)
        }

        var lines = [line("┌", "┬", "┐")]
        lines.append(dataRow(zip(headers, widths).map { " \(centered($0, width: $1)) " }))
        for row in rows {
            lines.append(line("├", "┼", "┤"))
            let cells = zip(row, widths).map { cell, width -> String in
                let content = cell.text + String(repeating: " ", count: width - cell.text.count)
                guard let prefix = cell.ansiPrefix else { return " \(content) " }
                return " \(prefix)\(content)\u{1B}[0m "
            }
            lines.append(dataRow(cells))
        }
        lines.append(line("└", "┴", "┘"))
        return lines.joined(separator: "\n")
    }
}
