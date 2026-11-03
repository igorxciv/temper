import Testing

@testable import TemperCore

struct SpokenDurationTests {
    @Test(arguments: [
        (Duration.seconds(296), "4 minutes 56 seconds"),
        (.seconds(600), "10 minutes"),
        (.seconds(65), "1 minute 5 seconds"),
        (.seconds(60), "1 minute"),
        (.seconds(1), "1 second"),
        (.seconds(8), "8 seconds"),
        (.seconds(610), "10 minutes 10 seconds"),
    ])
    func `Minutes and seconds read in words, dropping zero parts`(time: Duration, spoken: String) {
        #expect(time.spokenText(rounding: .up) == spoken)
    }

    @Test func `A zero time reads 0 seconds`() {
        #expect(Duration.zero.spokenText(rounding: .down) == "0 seconds")
        #expect(Duration.zero.spokenText(rounding: .up) == "0 seconds")
    }

    @Test func `Long totals keep counting in minutes, with no hours`() {
        #expect(Duration.seconds(7200).spokenText(rounding: .up) == "120 minutes")
    }

    @Test func `Part of a second rounds up for time left and down for time elapsed`() {
        let time = Duration.milliseconds(4_001)

        #expect(time.spokenText(rounding: .up) == "5 seconds")
        #expect(time.spokenText(rounding: .down) == "4 seconds")
    }

    @Test func `Rounding up can reach the next minute`() {
        #expect(Duration.milliseconds(59_500).spokenText(rounding: .up) == "1 minute")
    }

    @Test func `A negative time reads as zero`() {
        #expect(Duration.seconds(-3).spokenText(rounding: .up) == "0 seconds")
    }
}
