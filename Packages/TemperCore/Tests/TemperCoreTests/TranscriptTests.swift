import Testing

@testable import TemperCore

struct TranscriptTests {
    @Test func `A new Transcript has no words`() {
        #expect(Transcript().text == "")
    }

    @Test func `Words still being revised show at once, and each revision replaces the last`() {
        var transcript = Transcript()
        transcript.hear("ten", isFinal: false)
        transcript.hear("ten sets", isFinal: false)
        #expect(transcript.text == "ten sets")
    }

    @Test func `Settled words stay, and the next words follow them`() {
        var transcript = Transcript()
        transcript.hear("10 sets,", isFinal: true)
        transcript.hear(" open", isFinal: false)
        #expect(transcript.text == "10 sets, open")
        transcript.hear(" open Work.", isFinal: true)
        #expect(transcript.text == "10 sets, open Work.")
    }

    @Test func `Settled words clear the revision they replace`() {
        var transcript = Transcript()
        transcript.hear("tin sets", isFinal: false)
        transcript.hear("10 sets", isFinal: true)
        #expect(transcript.text == "10 sets")
    }

    @Test func `Pieces with no space between them get one`() {
        var transcript = Transcript()
        transcript.hear("10 sets.", isFinal: true)
        transcript.hear("1 minute of Rest", isFinal: true)
        #expect(transcript.text == "10 sets. 1 minute of Rest")
    }

    @Test func `Space at either end is dropped`() {
        var transcript = Transcript()
        transcript.hear("  10 sets ", isFinal: true)
        transcript.hear(" ", isFinal: false)
        #expect(transcript.text == "10 sets")
    }
}
