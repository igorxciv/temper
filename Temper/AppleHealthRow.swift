/// The one row in Settings' Apple Health section.
enum AppleHealthRow {
    /// "Save Workouts to Health": the owner hasn't been asked.
    case saveWorkouts
    /// "Allow Heart Rate": workouts are allowed, but the reads the Watch needs haven't been asked for yet.
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
}
