/// The row in Settings' Apple Health section.
enum AppleHealthRow {
    /// "Save Workouts to Health": the owner hasn't been asked.
    case saveWorkouts
    /// The switch on, with "Allow Heart Rate" under it: workouts are allowed, but the reads the Watch needs haven't
    /// been asked for yet.
    case allowHeartRate
    /// The switch on: nothing is left to ask.
    case saving
    /// The switch off: workouts are allowed, but the owner turned saving off in Temper.
    case off
    /// "Not allowed": the owner said no to workouts, or the device has no Health.
    case notAllowed

    /// `isOn` is the owner's switch in Settings, which counts only once workouts are allowed.
    init(writeStatus: HealthWriteStatus, requestStatus: HealthRequestStatus, isOn: Bool) {
        switch (writeStatus, requestStatus) {
        case (.notDetermined, _): self = .saveWorkouts
        case (.allowed, _) where !isOn: self = .off
        case (.allowed, .shouldRequest): self = .allowHeartRate
        case (.allowed, .unnecessary): self = .saving
        case (.denied, _): self = .notAllowed
        }
    }

    /// The section's footer under this row.
    var footer: String {
        let saves = "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch."
        switch self {
        case .saveWorkouts, .saving: return saves
        case .allowHeartRate: return "\(saves) Apple Watch shows your heart rate and saves it to Health."
        case .off: return "Workouts aren't saved to Health. Apple Watch still follows each one."
        case .notAllowed: return "Allow Temper under Settings › Health › Data Access & Devices."
        }
    }
}
