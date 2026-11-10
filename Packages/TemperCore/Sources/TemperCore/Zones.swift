import Foundation

/// The five Zones of one Workout, worked out by the heart-rate reserve method, so a bpm can be placed in its Zone.
///
/// watchOS 27's zone APIs don't run on a Series 8, so Temper works the Zones out itself, once when the Watch's session
/// starts. They then stay fixed until Stop.
public nonisolated struct Zones: Equatable, Sendable {
    /// The lowest bpm of Zones 2, 3, 4 and 5. Zone 1 is everything below the first.
    let lowerBounds: [Double]

    /// The maximum is Tanaka's 208 − 0.7 × age, with the age in whole years on the day of `start`. Each boundary is
    /// `restingHeartRate` + p × (maximum − `restingHeartRate`), for p of 60, 70, 80 and 90%.
    ///
    /// `nil` when `dateOfBirth` isn't a date in `calendar`.
    public init?(dateOfBirth: DateComponents, restingHeartRate: Double, start: Date, calendar: Calendar) {
        guard let birth = calendar.date(from: dateOfBirth),
            let age = calendar.dateComponents([.year], from: birth, to: start).year
        else { return nil }
        // In tenths and hundredths, so whole inputs make exact boundaries.
        let maximum = 208 - Double(7 * age) / 10
        let reserve = maximum - restingHeartRate
        lowerBounds = [60.0, 70, 80, 90].map { restingHeartRate + reserve * $0 / 100 }
    }

    /// The Zone, from 1 to 5, that `bpm` falls in. Each Zone includes its lower boundary, and `bpm` is compared with the
    /// exact boundaries, not rounded ones. A bpm under the resting rate is in Zone 1, and one over the maximum in Zone 5.
    public func zone(of bpm: Double) -> Int {
        1 + lowerBounds.count { bpm >= $0 }
    }
}
