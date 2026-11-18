/// The one row in Settings' Apple Watch section.
enum HeartRateRow {
    /// "Heart Rate", "Allow": some of the set hasn't been asked for yet.
    case allowHeartRate
    /// "Heart Rate", "Allowed": nothing is left to ask.
    case allowed
    /// "Heart Rate", "Not Allowed": the owner said no to workouts, which the Watch's session needs, or the device has
    /// no Health.
    case notAllowed

    init(writeStatus: HealthWriteStatus, requestStatus: HealthRequestStatus) {
        switch (writeStatus, requestStatus) {
        case (.notDetermined, _), (.allowed, .shouldRequest): self = .allowHeartRate
        case (.allowed, .unnecessary): self = .allowed
        case (.denied, _): self = .notAllowed
        }
    }

    /// The section's footer under this row.
    var footer: String {
        switch self {
        case .allowHeartRate, .allowed:
            "Apple Watch shows your heart rate and Zone during a Workout. Temper saves nothing to Health."
        case .notAllowed:
            "Allow Temper under Settings › Health › Data Access & Devices."
        }
    }
}
