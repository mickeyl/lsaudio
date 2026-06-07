import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List processes that are currently playing or recording audio (default)."
    )

    @Argument(help: "Only show processes whose name or bundle ID contains this text.")
    var pattern: String?

    @Flag(name: .shortAndLong, help: "Show every process registered with coreaudiod, including idle ones.")
    var all = false

    @Flag(name: [.customShort("j"), .long], help: "Output JSON.")
    var json = false

    @Flag(name: [.customShort("p"), .long], help: "Output plain tab-separated text.")
    var plain = false

    @Flag(name: [.customShort("w"), .long], help: "Watch for changes: redraw on a TTY, emit events when piped.")
    var watch = false

    @Flag(name: [.customLong("no-color")], help: "Disable colored output.")
    var noColor = false

    func validate() throws {
        guard !(json && plain) else { throw ValidationError("Choose either --json or --plain, not both.") }
        guard !(json && watch) else { throw ValidationError("--watch cannot be combined with --json.") }
    }

    func run() throws {
        let style = OutputStyle(noColorFlag: noColor)

        if watch {
            Watcher(all: all, pattern: pattern, plainEvents: plain || !style.colorized, style: style).run()
        }

        let processes = Self.selectedProcesses(all: all, pattern: pattern)

        if json {
            print(try ProcessRenderer.json(for: processes))
            return
        }
        if plain || isatty(STDOUT_FILENO) != 1 {
            guard !processes.isEmpty else { return }
            print(ProcessRenderer.plain(for: processes))
            return
        }
        guard !processes.isEmpty else {
            print(emptyMessage)
            return
        }
        print(ProcessRenderer.table(for: processes, style: style))
    }

    static func selectedProcesses(all: Bool, pattern: String?) -> [AudioProcess] {
        var processes = AudioProcess.snapshot()
        if !all {
            processes = processes.filter(\.isActive)
        }
        guard let pattern else { return processes }
        return processes.filter {
            $0.name.localizedCaseInsensitiveContains(pattern)
                || ($0.bundleID?.localizedCaseInsensitiveContains(pattern) ?? false)
        }
    }

    private var emptyMessage: String {
        if let pattern {
            return all
                ? "No registered audio process matches «\(pattern)»."
                : "No active audio process matches «\(pattern)» — try --all to include idle clients."
        }
        return "No processes are currently playing or recording audio."
    }
}
