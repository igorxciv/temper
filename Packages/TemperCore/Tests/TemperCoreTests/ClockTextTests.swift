import Testing

@testable import TemperCore

struct ClockTextTests {
    @Test(arguments: [
        (Duration.zero, "00:00"),
        (.seconds(5), "00:05"),
        (.seconds(60), "01:00"),
        (.seconds(530), "08:50"),
        (.seconds(1800), "30:00"),
    ])
    func `Every time reads minutes and seconds`(time: Duration, text: String) {
        #expect(time.clockText == text)
    }

    @Test(arguments: [
        (Duration.milliseconds(1), "00:01"),
        (.milliseconds(4_001), "00:05"),
        (.milliseconds(59_500), "01:00"),
        (.nanoseconds(1), "00:01"),
    ])
    func `Part of a second rounds up`(time: Duration, text: String) {
        #expect(time.clockText == text)
    }

    @Test(arguments: [
        (Duration.milliseconds(999), "00:00"),
        (.milliseconds(4_001), "00:04"),
        (.milliseconds(59_999), "00:59"),
        (.seconds(60), "01:00"),
    ])
    func `A time elapsed drops part of a second`(time: Duration, text: String) {
        #expect(time.clockText(rounding: .down) == text)
    }

    @Test func `Long totals keep counting in minutes, with no hours`() {
        #expect(Duration.seconds(7200).clockText == "120:00")
    }

    @Test func `A negative time reads as zero`() {
        #expect(Duration.seconds(-3).clockText == "00:00")
    }
}
