import LSAudioCore
import Testing

@Suite("Audio signal parsing")
struct AudioSignalTests {
    @Test("Parses names with or without SIG prefix")
    func names() throws {
        #expect(try AudioSignal.parse("TERM") == .term)
        #expect(try AudioSignal.parse("sigterm") == .term)
    }

    @Test("Preserves supported numeric signals")
    func numbers() throws {
        #expect(try AudioSignal.parse("9").number == 9)
    }

    @Test("Rejects unknown signals")
    func invalid() {
        #expect(throws: AudioSignalError.self) { try AudioSignal.parse("NOPE") }
    }
}
