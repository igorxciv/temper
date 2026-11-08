import TemperCore

/// Where Health workouts are saved: HealthKit in the app, and a fake in tests.
protocol HealthWorkoutStore {
    var writeStatus: HealthWriteStatus { get }
    /// Whether asking for the full set, sharing workouts and the reads the Watch needs, would show the system sheet.
    var requestStatus: HealthRequestStatus { get async }
    /// Shows the system sheet asking for the full set, if any of it hasn't been answered yet.
    func requestPermission() async
    func save(_ record: HealthRecord) async -> HealthSaveOutcome
}
