import Foundation

/// The five Zones of one Workout, worked out by the heart-rate reserve method, so a bpm can be placed in its Zone.
///
/// watchOS 27's zone APIs don't run on a Series 8, so Temper works the Zones out itself, once when the Watch's session
/// starts. They then stay fixed until Stop.
///
/// Apple doesn't publish how it sets its own Zones, and watchOS 26 can't read them, but Apple Watch users report this
/// same reserve split. The Zones are only shown, never saved with the Health workout, because watchOS 26 can't save
/// time in a Zone. On watchOS 27 these boundaries could go to HealthKit's own zone configuration in place of this
/// lookup.
public nonisolated struct Zones: Equatable, Sendable {
    /// The lowest bpm of Zones 2, 3, 4 and 5. Zone 1 is everything below the first.
    let lowerBounds: [Double]

    /// The maximum is Tanaka's 208 − 0.7 × age, with the age in whole years on the day of `start`. Each boundary is
    /// `restingHeartRate` + p × (maximum − `restingHeartRate`), for p of 60, 70, 80 and 90%. Tanaka won over 220 − age
    /// and over the highest bpm seen, which is noisy because the Watch purges old samples.
    ///
    /// `nil` when `dateOfBirth` isn't a date in `calendar`.
    public init?(dateOfBirth: DateComponents, restingHeartRate: Double, start: Date, calendar: Calendar) {
        guard let birth = calendar.date(from: dateOfBirth),
            let age = calendar.dateComponents([.year], from: birth, to: start).year
        else { return nil }
        // Scaled from whole tenths and percents, so a boundary that is a whole bpm comes out as exactly that bpm.
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
