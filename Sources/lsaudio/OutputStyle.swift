import Foundation

/// Decides whether ANSI styling may be used, honoring --no-color, NO_COLOR, TERM=dumb, and TTY detection.
struct OutputStyle {
    let colorized: Bool

    init(noColorFlag: Bool) {
        let environment = ProcessInfo.processInfo.environment
        if noColorFlag || environment["NO_COLOR"]?.isEmpty == false || environment["TERM"] == "dumb" {
            colorized = false
        } else {
            colorized = isatty(STDOUT_FILENO) == 1
        }
    }

    var greenPrefix: String? { colorized ? "\u{1B}[32m" : nil }
    var redPrefix: String? { colorized ? "\u{1B}[31m" : nil }
    var dimPrefix: String? { colorized ? "\u{1B}[2m" : nil }

    func dimmed(_ text: String) -> String {
        guard let prefix = dimPrefix else { return text }
        return "\(prefix)\(text)\u{1B}[0m"
    }
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
