/// Where Temper's Health permission is read and asked for: HealthKit in the app, and a fake in tests.
protocol HealthPermissionStore {
    /// Whether Temper may share workouts, which the Watch's workout session stands on.
    var writeStatus: HealthWriteStatus { get }
    /// Whether asking for the full set, sharing workouts and the reads the Watch needs, would show the system sheet.
    var requestStatus: HealthRequestStatus { get async }
    /// Shows the system sheet asking for the full set, if any of it hasn't been answered yet.
    func requestPermission() async
}
