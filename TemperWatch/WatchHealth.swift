import Foundation
import HealthKit
import TemperCore

/// What the Watch reads of its Health permission. It never asks: the iPhone's Settings asks once, and the Watch shares
/// that grant. The Watch keeps both usage strings only in case a later watchOS separates the grants.
enum WatchHealth {
    private static let store = HKHealthStore()

    /// Whether the Watch may save Health workouts. The iPhone opens the Watch at Start only when this holds on the
    /// iPhone.
    static var workoutsAllowed: Bool {
        HKHealthStore.isHealthDataAvailable() && store.authorizationStatus(for: .workoutType()) == .sharingAuthorized
    }

    /// What the Zones are worked out from: the date of birth and the newest resting heart rate, however old. Health
    /// returns nothing for a read that isn't allowed, so a missing value and a denied one look the same.
    struct ZoneInputs: Sendable {
        let dateOfBirth: DateComponents?
        let restingHeartRate: Double?

        /// `nil` without either input, which hides the Zone meter for the Workout.
        func zones(start: Date) -> Zones? {
            guard let dateOfBirth, let restingHeartRate else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            return Zones(dateOfBirth: dateOfBirth, restingHeartRate: restingHeartRate, start: start, calendar: calendar)
        }
    }

    static func zoneInputs() async -> ZoneInputs {
        let dateOfBirth = try? store.dateOfBirthComponents()
        let newest = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        let resting = try? await newest.result(for: store).first?.quantity.doubleValue(for: .beatsPerMinute)
        return ZoneInputs(dateOfBirth: dateOfBirth, restingHeartRate: resting)
    }
}

extension HKUnit {
    nonisolated static var beatsPerMinute: HKUnit { .count().unitDivided(by: .minute()) }
}
