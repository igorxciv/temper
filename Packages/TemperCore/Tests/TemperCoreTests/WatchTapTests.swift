import Foundation
import Testing

@testable import TemperCore

/// Where a tap the Watch dated on its own clock lands on the iPhone engine's clock.
nonisolated struct WatchTapTests {
    private typealias Instant = ManualClock.Instant

    /// The tap reached the iPhone at 100 s on the engine clock, which read this date.
    private let arrival = ClockAnchor(
        instant: Instant(offset: .seconds(100)), date: Date(timeIntervalSinceReferenceDate: 1_000_000))

    @Test func `A tap is placed as far back as it was old on arrival`() {
        let tap = arrival.date.addingTimeInterval(-0.5)

        #expect(WatchTap.instant(of: tap, arrival: arrival) == Instant(offset: .milliseconds(99_500)))
    }

    @Test func `A tap exactly 2 s old on arrival is still placed`() {
        let tap = arrival.date.addingTimeInterval(-2)

        #expect(WatchTap.instant(of: tap, arrival: arrival) == Instant(offset: .seconds(98)))
    }

    @Test func `A tap more than 2 s old on arrival is refused`() {
        let tap = arrival.date.addingTimeInterval(-2.25)

        #expect(WatchTap.instant(of: tap, arrival: arrival) == nil)
    }

    /// The engine clamps it to no later than now, as it does every tap.
    @Test func `A tap dated after its arrival, by a Watch clock running ahead, is placed after it`() {
        let tap = arrival.date.addingTimeInterval(0.25)

        #expect(WatchTap.instant(of: tap, arrival: arrival) == Instant(offset: .milliseconds(100_250)))
    }
}
