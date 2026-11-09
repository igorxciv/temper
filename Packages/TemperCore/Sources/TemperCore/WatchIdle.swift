/// What the Watch says outside a Workout. The Watch can't start one, so it points to the iPhone.
public nonisolated enum WatchIdle: Equatable, Sendable {
    /// Workouts are allowed in Health, so the iPhone opens the Watch at the next Start.
    case startOnIPhone
    /// Workouts aren't allowed in Health. The iPhone then runs every Workout alone and never opens the Watch, so the
    /// Watch points to the only place that asks.
    case turnOnHealth

    /// `workoutsAllowed` is the Watch's own workout status, which is the iPhone's, because the two share one grant.
    public init(workoutsAllowed: Bool) {
        self = workoutsAllowed ? .startOnIPhone : .turnOnHealth
    }

    public var title: String {
        switch self {
        case .startOnIPhone: "Start on iPhone"
        case .turnOnHealth: "Turn on Apple Health in Temper’s Settings on iPhone"
        }
    }

    /// The smaller line under the title. The title already says everything when workouts aren't allowed.
    public var message: String? {
        switch self {
        case .startOnIPhone: "Pick a Workout on your iPhone and tap Start."
        case .turnOnHealth: nil
        }
    }
}
