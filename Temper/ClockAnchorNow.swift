import Foundation
import TemperCore

extension ClockAnchor<ContinuousClock.Instant> {
    /// The engine clock and the wall clock, read together now. It places a Health record's times, and a Watch tap's
    /// arrival.
    nonisolated static var now: Self {
        Self(instant: ContinuousClock.now, date: Date.now)
    }
}
