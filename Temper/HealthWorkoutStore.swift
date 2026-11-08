import TemperCore

/// Where Health workouts are saved: HealthKit in the app, and a fake in tests.
protocol HealthWorkoutStore {
    var writeStatus: HealthWriteStatus { get }
    /// Shows the system sheet asking to write workouts, if the owner hasn't answered it yet.
    func requestPermission() async
    func save(_ record: HealthRecord) async -> HealthSaveOutcome
}
