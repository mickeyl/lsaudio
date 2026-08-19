import Darwin
import Foundation
import LSAudioCore

struct SignalDeliveryResult: Sendable {
    let deliveredCount: Int
    let permissionDenied: [AudioProcess]
    let failures: [String]
}

actor ProcessSignaler {
    static let shared = ProcessSignaler()

    func send(
        _ signal: AudioSignal,
        to processes: [AudioProcess],
        authorizeIfNeeded: Bool
    ) -> SignalDeliveryResult {
        var deliveredCount = 0
        var denied: [AudioProcess] = []
        var failures: [String] = []

        for process in processes {
            if Darwin.kill(process.pid, signal.number) == 0 {
                deliveredCount += 1
            } else if errno == EPERM {
                denied.append(process)
            } else {
                failures.append("\(process.name) (PID \(process.pid)): \(String(cString: strerror(errno)))")
            }
        }

        if authorizeIfNeeded, !denied.isEmpty {
            do {
                try privilegedKill(signal: signal, processes: denied)
                deliveredCount += denied.count
                denied.removeAll()
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        return SignalDeliveryResult(
            deliveredCount: deliveredCount,
            permissionDenied: denied,
            failures: failures
        )
    }

    private func privilegedKill(signal: AudioSignal, processes: [AudioProcess]) throws {
        let pids = processes.map { String($0.pid) }.joined(separator: " ")
        let command = "/bin/kill -\(signal.number) \(pids)"
        let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let task = Process()
        let errorPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        task.standardError = errorPipe
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PrivilegedSignalError(message: message ?? "Administrator authorization failed.")
        }
    }
}

private struct PrivilegedSignalError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
