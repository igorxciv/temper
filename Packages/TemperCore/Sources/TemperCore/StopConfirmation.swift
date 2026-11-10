import Foundation

/// Stop on the Watch's secondary page, which asks by a second tap rather than a dialog.
///
/// The first tap turns Stop solid red, reading "Tap to end". A second tap within ``window`` ends the Workout. After
/// that Stop goes back to Stop, and the next tap asks again. The iPhone keeps its "End this Workout?" dialog.
public nonisolated struct StopConfirmation: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        /// Stop now reads "Tap to end" and waits for a second tap.
        case askAgain
        /// The second tap came in time, so the Workout ends.
        case end
    }

    /// How long after the first tap a second one ends the Workout.
    public static var window: Duration { .seconds(3) }

    /// When an asking Stop goes back to Stop, or `nil` while it reads Stop.
    public private(set) var expiry: Date?

    public init() {}

    /// Whether Stop reads "Tap to end" at `date`. At ``expiry`` it already reads Stop again.
    public func isArmed(at date: Date) -> Bool {
        expiry.map { date < $0 } ?? false
    }

    /// A tap on Stop at `date` on the Watch's clock.
    public mutating func tap(at date: Date) -> Outcome {
        if isArmed(at: date) {
            expiry = nil
            return .end
        }
        expiry = date.addingTimeInterval(Self.window / .seconds(1))
        return .askAgain
    }
}
