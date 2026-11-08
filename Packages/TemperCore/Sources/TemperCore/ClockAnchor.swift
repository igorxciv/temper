import Foundation

/// An instant on the engine clock and the wall-clock date read together with it, which places any other instant as a
/// date. The engine's clock keeps counting while the iPhone sleeps, so one anchor places every instant of a Workout.
public nonisolated struct ClockAnchor<Instant: InstantProtocol>: Sendable where Instant.Duration == Duration {
    public let instant: Instant
    public let date: Date

    public init(instant: Instant, date: Date) {
        self.instant = instant
        self.date = date
    }

    /// The wall-clock date of `other`.
    public func date(of other: Instant) -> Date {
        date.addingTimeInterval(instant.duration(to: other) / .seconds(1))
    }
}
