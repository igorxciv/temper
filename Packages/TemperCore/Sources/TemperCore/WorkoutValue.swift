/// One of the five values setup edits. Its amount is a count of Rounds, or a time in whole seconds.
public nonisolated enum WorkoutValue: CaseIterable, Hashable, Identifiable, Sendable {
    case prepare, rounds, work, rest, cooldown

    public var id: Self { self }

    /// The Phase this value times. Rounds has none.
    public var phaseKind: Phase.Kind? {
        switch self {
        case .prepare: .prepare
        case .rounds: nil
        case .work: .work
        case .rest: .rest
        case .cooldown: .cooldown
        }
    }

    public var isTime: Bool {
        self != .rounds
    }

    /// What the value sheet's wheels offer: one wheel of Rounds, or two wheels of minutes and seconds for a time.
    public static let roundChoices = Array(1...99)
    public static let minuteChoices = Array(0...30)
    public static let secondChoices = Array(stride(from: 0, to: 60, by: 5))

    /// The nearest amount this value allows. A time stops at 30:00 because a locked iPhone has been seen to stay
    /// alive through 30 minutes of silence between Cues, and no longer.
    public func clamped(_ amount: Int) -> Int {
        switch self {
        case .rounds: min(max(amount, 1), 99)
        case .work: min(max(onStep(amount), 5), 1800)
        case .prepare, .rest, .cooldown: min(max(onStep(amount), 0), 1800)
        }
    }

    /// The amount two time wheels point at, once clamped. 30 minutes forces the seconds to 00.
    public func amount(minutes: Int, seconds: Int) -> Int {
        clamped(minutes * 60 + seconds)
    }

    /// How an amount reads on setup.
    public func text(for amount: Int) -> String {
        switch self {
        case .rounds: "\(amount)"
        case .prepare, .work, .rest, .cooldown: amount == 0 ? "Off" : Duration.seconds(amount).clockText
        }
    }

    private func onStep(_ seconds: Int) -> Int {
        seconds - seconds % 5
    }
}

extension WorkoutSettings {
    /// The amount of one value, with no clamping. Pass it through `WorkoutValue.clamped(_:)` first.
    public nonisolated subscript(value: WorkoutValue) -> Int {
        get {
            switch value {
            case .prepare: Int(prepare.components.seconds)
            case .rounds: rounds
            case .work: Int(work.components.seconds)
            case .rest: Int(rest.components.seconds)
            case .cooldown: Int(cooldown.components.seconds)
            }
        }
        set {
            switch value {
            case .prepare: prepare = .seconds(newValue)
            case .rounds: rounds = newValue
            case .work: work = .seconds(newValue)
            case .rest: rest = .seconds(newValue)
            case .cooldown: cooldown = .seconds(newValue)
            }
        }
    }
}
