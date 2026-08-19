import Darwin

public struct AudioSignal: Identifiable, Hashable, Sendable {
    public let name: String
    public let number: Int32
    public var id: Int32 { number }
    public var label: String { "SIG\(name)" }

    public static let supported: [AudioSignal] = [
        AudioSignal(name: "HUP", number: SIGHUP),
        AudioSignal(name: "INT", number: SIGINT),
        AudioSignal(name: "QUIT", number: SIGQUIT),
        AudioSignal(name: "KILL", number: SIGKILL),
        AudioSignal(name: "TERM", number: SIGTERM),
        AudioSignal(name: "USR1", number: SIGUSR1),
        AudioSignal(name: "USR2", number: SIGUSR2),
        AudioSignal(name: "STOP", number: SIGSTOP),
        AudioSignal(name: "CONT", number: SIGCONT),
    ]

    public static let term = AudioSignal(name: "TERM", number: SIGTERM)

    public static func parse(_ value: String) throws -> AudioSignal {
        if let number = Int32(value) {
            guard number > 0, number < NSIG else {
                throw AudioSignalError.outOfRange(number: number, maximum: NSIG - 1)
            }
            return supported.first(where: { $0.number == number })
                ?? AudioSignal(name: "", number: number)
        }
        var name = value.uppercased()
        if name.hasPrefix("SIG") { name.removeFirst(3) }
        guard let signal = supported.first(where: { $0.name == name }) else {
            throw AudioSignalError.unknown(value)
        }
        return signal
    }
}

public enum AudioSignalError: Error, Equatable, Sendable {
    case outOfRange(number: Int32, maximum: Int32)
    case unknown(String)
}
