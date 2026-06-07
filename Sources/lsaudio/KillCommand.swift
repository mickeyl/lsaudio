import ArgumentParser
import Darwin
import Foundation

struct Kill: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a signal to audio processes matching a PID, bundle ID, or name.",
        discussion: """
        By default only processes that are actively playing or recording are matched, \
        so a stray «afplay» can be ended without hitting idle audio clients. \
        Without a target, every active audio process is matched — «lsaudio kill» \
        simply makes the noise stop.

        Exit status: 0 on success, 1 if nothing matched, 2 if aborted or \
        confirmation was impossible, 3 if sending a signal failed.
        """
    )

    private static let signalsByName: [String: Int32] = [
        "HUP": SIGHUP, "INT": SIGINT, "QUIT": SIGQUIT, "KILL": SIGKILL,
        "TERM": SIGTERM, "USR1": SIGUSR1, "USR2": SIGUSR2, "STOP": SIGSTOP, "CONT": SIGCONT,
    ]

    @Argument(help: "A PID, a bundle ID, or a case-insensitive name substring. Omit to match every active audio process.")
    var target: String?

    @Option(name: [.customShort("s"), .customLong("signal")],
            help: "Signal to send, as name or number (e.g. TERM, KILL, 9).")
    var signalName: String = "TERM"

    @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.")
    var force = false

    @Flag(name: [.customShort("n"), .customLong("dry-run")], help: "Only show what would be signalled.")
    var dryRun = false

    @Flag(help: "Never prompt; fail instead. Useful for scripts.")
    var noInput = false

    @Flag(name: .shortAndLong, help: "Match among all registered audio processes, not only active ones.")
    var all = false

    @Flag(help: "Escalate via sudo when a target process belongs to another user.")
    var sudo = false

    func validate() throws {
        // Without a target, --all would signal every registered audio client,
        // including system daemons like corespeechd — never what anyone wants.
        guard !(all && target == nil) else {
            throw ValidationError("Refusing to signal every registered audio client. Give a target, or omit --all to address only active processes.")
        }
    }

    func run() throws {
        let (signalNumber, signalLabel) = try parsedSignal()
        let matches = Self.matches(for: target, all: all)

        guard !matches.isEmpty else {
            if let target {
                printError("No \(all ? "registered" : "active") audio process matches «\(target)».")
                printError(all
                    ? "Run «lsaudio --all» to see what is registered."
                    : "Pass --all to also match idle audio clients.")
            } else {
                printError("No processes are currently playing or recording audio.")
            }
            throw ExitCode(1)
        }

        if dryRun {
            for match in matches {
                print("Would send \(signalLabel) to \(match.described)")
            }
            return
        }

        if !force {
            try confirm(matches: matches, signalLabel: signalLabel)
        }

        var failed = false
        var denied: [AudioProcess] = []
        for match in matches {
            guard kill(match.pid, signalNumber) == 0 else {
                if errno == EPERM {
                    denied.append(match)
                } else {
                    failed = true
                    printError("Failed to send \(signalLabel) to \(match.described): \(String(cString: strerror(errno)))")
                }
                continue
            }
            print("Sent \(signalLabel) to \(match.described)")
        }
        if !denied.isEmpty, try !escalate(denied, signalNumber: signalNumber, signalLabel: signalLabel) {
            failed = true
        }
        if failed { throw ExitCode(3) }
    }

    static func matches(for target: String?, all: Bool) -> [AudioProcess] {
        let candidates = List.selectedProcesses(all: all, pattern: nil)
        let matched: [AudioProcess] = if let target {
            if let pid = pid_t(target) {
                candidates.filter { $0.pid == pid }
            } else {
                candidates.filter {
                    $0.name.localizedCaseInsensitiveContains(target)
                        || ($0.bundleID?.localizedCaseInsensitiveContains(target) ?? false)
                }
            }
        } else {
            candidates
        }
        // Never offer to kill ourselves, even if the pattern matches.
        return matched.filter { $0.pid != getpid() }
    }

    private func confirm(matches: [AudioProcess], signalLabel: String) throws {
        for match in matches {
            printError("  \(match.described)")
        }
        guard !noInput, isatty(STDIN_FILENO) == 1 else {
            printError("Refusing to send \(signalLabel) without confirmation — pass --force to skip the prompt.")
            throw ExitCode(2)
        }
        let count = matches.count == 1 ? "1 process" : "\(matches.count) processes"
        FileHandle.standardError.write(Data("Send \(signalLabel) to \(count)? [y/N] ".utf8))
        guard let answer = readLine()?.lowercased(), ["y", "yes"].contains(answer) else {
            printError("Aborted.")
            throw ExitCode(2)
        }
    }

    /// Root-owned audio daemons (e.g. systemsoundserverd) yield EPERM; retry those via sudo,
    /// which handles authentication itself (password prompt or Touch ID).
    private func escalate(_ denied: [AudioProcess], signalNumber: Int32, signalLabel: String) throws -> Bool {
        for match in denied {
            printError("Not permitted to signal \(match.described) — the process belongs to another user.")
        }
        if !sudo {
            guard !noInput, isatty(STDIN_FILENO) == 1 else {
                printError("Re-run with --sudo (or under sudo) to escalate.")
                return false
            }
            FileHandle.standardError.write(Data("Retry with sudo? [y/N] ".utf8))
            guard let answer = readLine()?.lowercased(), ["y", "yes"].contains(answer) else {
                return false
            }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        // With --no-input, sudo must not sit waiting for a password (-n fails loudly instead).
        let sudoFlags = noInput ? ["-n"] : []
        process.arguments = sudoFlags + ["/bin/kill", "-\(signalNumber)"] + denied.map { String($0.pid) }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            printError("sudo kill exited with status \(process.terminationStatus).")
            return false
        }
        for match in denied {
            print("Sent \(signalLabel) to \(match.described) — as root")
        }
        return true
    }

    private func parsedSignal() throws -> (number: Int32, label: String) {
        if let number = Int32(signalName) {
            guard number > 0, number < NSIG else {
                throw ValidationError("Signal number \(number) is out of range (1–\(NSIG - 1)).")
            }
            let name = Self.signalsByName.first { $0.value == number }?.key
            return (number, name.map { "SIG\($0)" } ?? "signal \(number)")
        }
        var name = signalName.uppercased()
        if name.hasPrefix("SIG") { name.removeFirst(3) }
        guard let number = Self.signalsByName[name] else {
            let known = Self.signalsByName.keys.sorted().joined(separator: ", ")
            throw ValidationError("Unknown signal «\(signalName)». Use a number or one of: \(known).")
        }
        return (number, "SIG\(name)")
    }
}

private extension AudioProcess {
    var described: String {
        let bundle = bundleID.map { " (\($0))" } ?? ""
        return "\(name)\(bundle), PID \(pid) — \(activityDescription)"
    }
}
