/// Whether Temper may write workouts to Health.
enum HealthWriteStatus {
    /// The owner hasn't been asked.
    case notDetermined
    case allowed
    /// The owner said no, or the device has no Health.
    case denied
}
