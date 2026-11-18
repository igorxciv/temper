/// Settings' Heart Rate row, by what Health reports.
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

    /// The line under "Heart Rate".
    var subtitle: String {
        switch self {
        case .allowHeartRate, .allowed: "Shown on Apple Watch"
        case .notAllowed: "Change in Settings › Health"
        }
    }
}
