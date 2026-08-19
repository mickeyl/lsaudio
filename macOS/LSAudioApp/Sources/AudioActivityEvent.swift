import Foundation
import LSAudioCore

enum AudioEventAction: String, Sendable {
    case present
    case start
    case change
    case stop
}

struct AudioActivityEvent: Identifiable, Sendable {
    let id = UUID()
    let action: AudioEventAction
    let process: AudioProcess
    let timestamp: Date

    var plainLine: String {
        [
            Self.timestampFormatter.string(from: timestamp),
            action.rawValue,
            String(process.pid),
            process.name,
            process.bundleID ?? "-",
            channels,
        ]
        .joined(separator: "\t")
    }

    private var channels: String {
        switch (process.isRunningOutput, process.isRunningInput) {
        case (true, true): "output+input"
        case (true, false): "output"
        case (false, true): "input"
        case (false, false): "none"
        }
    }

    private static let timestampFormatter = ISO8601DateFormatter()
}
