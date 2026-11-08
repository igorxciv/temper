/// The one row in Settings' Apple Health section.
enum AppleHealthRow {
    /// "Save Workouts to Health": the owner hasn't been asked.
    case saveWorkouts
    /// "Saving to Health" with "Allow Heart Rate" where the checkmark goes: workouts are allowed, but the reads the
    /// Watch needs haven't been asked for yet.
    case allowHeartRate
    /// "Saving to Health" with a checkmark: nothing is left to ask.
    case saving
    /// "Not allowed": the owner said no to workouts, or the device has no Health.
    case notAllowed

    init(writeStatus: HealthWriteStatus, requestStatus: HealthRequestStatus) {
        switch (writeStatus, requestStatus) {
        case (.notDetermined, _): self = .saveWorkouts
        case (.allowed, .shouldRequest): self = .allowHeartRate
        case (.allowed, .unnecessary): self = .saving
        case (.denied, _): self = .notAllowed
        }
    }

    /// The section's footer under this row.
    var footer: String {
        let saves = "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch."
        switch self {
        case .saveWorkouts: return saves
        case .allowHeartRate: return "\(saves) Apple Watch shows your heart rate and saves it to Health."
        case .saving: return "\(saves) Turn this off in the Health app."
        case .notAllowed: return "Allow Temper under Settings › Health › Data Access & Devices."
        }
    }
}
