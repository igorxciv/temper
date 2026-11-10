import Foundation
import Testing

@testable import TemperCore

/// Stop on the Watch's secondary page asks by a second tap within 3 s, not by a dialog.
nonisolated struct StopConfirmationTests {
    private let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func `Stop reads Stop until it's tapped`() {
        #expect(!StopConfirmation().isArmed(at: date))
    }

    @Test func `The first tap asks for a second, and Stop reads Tap to end`() {
        var stop = StopConfirmation()

        #expect(stop.tap(at: date) == .askAgain)
        #expect(stop.isArmed(at: date.addingTimeInterval(2.5)))
    }

    @Test func `A second tap within 3 s ends the Workout`() {
        var stop = StopConfirmation()
        _ = stop.tap(at: date)

        #expect(stop.tap(at: date.addingTimeInterval(2.75)) == .end)
    }

    /// The Watch redraws Stop at `expiry`, so it reads Stop from that moment.
    @Test func `After 3 s Stop goes back to Stop, at the moment it says`() {
        var stop = StopConfirmation()
        _ = stop.tap(at: date)

        #expect(stop.expiry == date.addingTimeInterval(3))
        #expect(!stop.isArmed(at: date.addingTimeInterval(3)))
    }

    @Test func `A tap after 3 s asks again rather than ending`() {
        var stop = StopConfirmation()
        _ = stop.tap(at: date)

        #expect(stop.tap(at: date.addingTimeInterval(3.25)) == .askAgain)
        #expect(stop.tap(at: date.addingTimeInterval(4)) == .end)
    }

    @Test func `Once it has ended, Stop reads Stop again`() {
        var stop = StopConfirmation()
        _ = stop.tap(at: date)
        _ = stop.tap(at: date.addingTimeInterval(1))

        #expect(!stop.isArmed(at: date.addingTimeInterval(1)))
        #expect(stop.expiry == nil)
    }
}
