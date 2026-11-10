import Foundation

/// A wrist haptic the Watch plays for a Cue: one kind of tap, a few times over, with no sound.
///
/// A count is the simplest difference to feel mid-set, and the iPhone still speaks every Cue, so the haptic mostly needs
/// to be felt rather than told apart.
public nonisolated struct WristHaptic: Equatable, Sendable {
    /// The `WKHapticType` each tap plays.
    public enum Tap: Equatable, Sendable {
        case notification, success, click
    }

    /// From the start of one tap to the start of the next.
    public static let gap = Duration.milliseconds(700)

    public let tap: Tap
    public let count: Int

    public init(tap: Tap, count: Int) {
        self.tap = tap
        self.count = count
    }

    /// When each tap starts, after the first.
    public var offsets: [Duration] {
        (0..<count).map { Self.gap * $0 }
    }
}

nonisolated extension Cue {
    /// Its wrist haptic, by scheme B: `notification` counts Phase changes, `success` ends the Workout, and the weak
    /// `click` is kept for "10 seconds", which comes in a Rest while the wrist is still. Finish came after the scheme
    /// and has none yet.
    public var wristHaptic: WristHaptic? {
        switch self {
        case .work: WristHaptic(tap: .notification, count: 2)
        case .rest: WristHaptic(tap: .notification, count: 1)
        case .cooldown: WristHaptic(tap: .notification, count: 3)
        case .workoutComplete: WristHaptic(tap: .success, count: 2)
        case .tenSeconds: WristHaptic(tap: .click, count: 3)
        case .finish: nil
        }
    }
}

/// Which wrist haptics the Watch schedules and which it plays on arrival, for each update the iPhone sends: each Cue
/// plays once, at its date or on arrival.
///
/// Each update carries the Cues still to come in its Phase, dated, so their haptics are scheduled to land on time
/// rather than when an update happens to arrive, and a newer update replaces them all. A Phase reached at Done had no
/// end to schedule its Cue at, so its Cue plays when its update arrives, unless the haptic scheduled for it already
/// played.
public nonisolated struct CueHaptics: Equatable, Sendable {
    /// What to do as one update arrives, in this order.
    public struct Plan: Equatable, Sendable {
        /// Cancel every haptic scheduled for after the update's arrival. One due by then has played.
        public var cancelsScheduled: Bool
        /// The Cue to play at once.
        public var playsNow: Cue?
        /// The haptics to schedule, each at its date.
        public var schedules: [WatchCue]

        public init(cancelsScheduled: Bool = false, playsNow: Cue? = nil, schedules: [WatchCue] = []) {
            self.cancelsScheduled = cancelsScheduled
            self.playsNow = playsNow
            self.schedules = schedules
        }
    }

    /// The Phases of a Workout differ in kind or Round, so these tell a new Phase from another update of the same one.
    private struct PhaseID: Equatable, Sendable {
        let kind: Phase.Kind
        let round: Int?
    }

    /// What the last update scheduled.
    private var scheduled: [WatchCue] = []
    /// The Phase of the last update, or `nil` after the end or before any update.
    private var phase: PhaseID?

    public init() {}

    /// The plan for `state`, arriving at `arrival` on the Watch's clock.
    ///
    /// A Phase's own Cue plays on arrival only as the Phase is new, and only within `lateLimit` of its start, the
    /// iPhone's own limit for a late Cue. So an update resent to a Watch that joins late or reconnects mid-Phase plays
    /// nothing for a Phase change long past.
    public mutating func plan(for state: WatchState, arrivingAt arrival: Date) -> Plan {
        let played = scheduled.filter { $0.date <= arrival }.map(\.cue)
        var plan = Plan(cancelsScheduled: scheduled.contains { $0.date > arrival })
        scheduled = []
        guard case .phase(let current) = state else {
            phase = nil
            return plan
        }
        let id = PhaseID(kind: current.kind, round: current.round)
        let isNew = id != phase
        phase = id
        if isNew, let cue = Cue(entering: current.kind), !played.contains(cue),
            arrival.timeIntervalSince(current.start) <= lateLimit / .seconds(1)
        {
            plan.playsNow = cue
        }
        scheduled = current.cues.filter { $0.date > arrival && $0.cue.wristHaptic != nil }
        plan.schedules = scheduled
        return plan
    }

    /// Forgets every haptic scheduled, as the link or the session goes, and returns whether there were any to cancel.
    public mutating func cancelAll() -> Bool {
        defer { scheduled = [] }
        return !scheduled.isEmpty
    }
}
