import HealthKit

/// What the Watch reads of its Health permission. It never asks: the iPhone's Settings asks once, and the Watch shares
/// that grant. The Watch keeps both usage strings only in case a later watchOS separates the grants.
enum WatchHealth {
    private static let store = HKHealthStore()

    /// Whether the Watch may save workouts. The iPhone opens the Watch at Start only when this holds on the iPhone.
    static var workoutsAllowed: Bool {
        HKHealthStore.isHealthDataAvailable() && store.authorizationStatus(for: .workoutType()) == .sharingAuthorized
    }
}
