import Testing

@testable import TemperCore

struct DictatedDescriptionTests {
    @Test func `Until words are heard, the earlier description stays`() {
        let description = DictatedDescription(replacing: "5 Rounds of 30 seconds")

        #expect(description.text == "5 Rounds of 30 seconds")
        #expect(!description.hasHeardWords)
    }

    @Test func `The first words heard replace the earlier description`() {
        var description = DictatedDescription(replacing: "5 Rounds of 30 seconds")

        description.hear("10 sets", isSettled: false)

        #expect(description.text == "10 sets")
        #expect(description.hasHeardWords)
    }

    @Test func `Tentative words replace the last tentative words`() {
        var description = DictatedDescription(replacing: "")

        description.hear("10 sex", isSettled: false)
        description.hear("10 sets of", isSettled: false)

        #expect(description.text == "10 sets of")
    }

    @Test func `Settled words stay, and later words follow them after a space`() {
        var description = DictatedDescription(replacing: "")

        description.hear("10 sets, open Work.", isSettled: true)
        description.hear("1 minute", isSettled: false)
        #expect(description.text == "10 sets, open Work. 1 minute")

        description.hear("1 minute of Rest.", isSettled: true)
        #expect(description.text == "10 sets, open Work. 1 minute of Rest.")
    }

    @Test func `Settling clears the tentative words they stood in for`() {
        var description = DictatedDescription(replacing: "")

        description.hear("Tabata", isSettled: false)
        description.hear("Tabata.", isSettled: true)

        #expect(description.text == "Tabata.")
    }

    @Test func `Spaces the recognizer puts at the edges don't double up`() {
        var description = DictatedDescription(replacing: "")

        description.hear(" 8 Rounds ", isSettled: true)
        description.hear(" of 20 seconds", isSettled: true)

        #expect(description.text == "8 Rounds of 20 seconds")
    }

    @Test func `Only silence heard leaves the earlier description`() {
        var description = DictatedDescription(replacing: "Tabata")

        description.hear("  ", isSettled: true)
        description.hear("", isSettled: false)

        #expect(description.text == "Tabata")
        #expect(!description.hasHeardWords)
    }
}
