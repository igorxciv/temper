import Foundation

/// What the Watch draws for a running Workout, ready to draw, as the iPhone sends it on every event.
///
/// The Watch keeps no Workout logic of its own. Like the Live Activity, it gets dates and draws the seconds from them,
/// so the iPhone sends a new state only when the snapshot changes, never on a tick.
public nonisolated enum WatchState: Codable, Hashable, Sendable {
    case phase(WatchPhase)
    /// The Workout has ended, with the complete screen it ends on, or `nil` when a Stop in Intervals or Stopwatch
    /// returns the iPhone to setup and the Watch to idle.
    case ended(Completion?)
}

/// A Phase on the Watch's running screen, running or Paused.
///
/// It differs from the Live Activity's `LivePhase` in carrying the Round, the running screen's full line rather than
/// the short one, and Open Rounds' dimmed Done in place of no button.
public nonisolated struct WatchPhase: Codable, Hashable, Sendable {
    /// What the capsule at the foot of the running screen says: the iPhone's quick action.
    public enum Capsule: String, Codable, Hashable, Sendable {
        case pause
        case resume
        /// Ends a running open Work, or a running Stopwatch Work past its set length.
        case done
        /// Open Rounds' Done, kept in place but dimmed in a Rest or while Paused, so nothing moves under the thumb.
        case doneDimmed

        /// What a tap on the capsule asks the iPhone to do, or `nil` for a dimmed Done, which takes no tap.
        public var command: WatchCommand? {
            switch self {
            case .pause: .pause
            case .resume: .resume
            case .done: .done
            case .doneDimmed: nil
            }
        }
    }

    public let kind: Phase.Kind
    /// The Round a Work or Rest belongs to, or `nil` for Prepare, Cooldown and a Stopwatch's Work.
    public let round: Int?
    /// When the Phase would have started if it ran without a Pause up to the snapshot.
    public let start: Date
    /// When the Phase would end if it ran without a Pause from the snapshot on, or `nil` for an open Phase. For a
    /// Stopwatch's Work it's when the Work reaches its set length, and its time counts on past it.
    public let end: Date?
    /// The time at which a Paused Phase is held, or `nil` while it runs.
    public let pausedAt: Date?
    /// True during a Stopwatch's Work and an open Phase, which count up from `start`.
    public let countsUp: Bool
    /// The line under the iPhone's ring, spoken text included, or `nil` when there's nothing to say.
    public let line: RingLine?
    public let capsule: Capsule
    /// The Cues due before the next update, which the Watch marks with wrist haptics: those still to come in a
    /// running Phase, up to its end. A Paused Phase has none.
    public let cues: [WatchCue]

    public init(
        kind: Phase.Kind, round: Int?, start: Date, end: Date?, pausedAt: Date?, countsUp: Bool, line: RingLine?,
        capsule: Capsule, cues: [WatchCue] = []
    ) {
        self.kind = kind
        self.round = round
        self.start = start
        self.end = end
        self.pausedAt = pausedAt
        self.countsUp = countsUp
        self.line = line
        self.capsule = capsule
        self.cues = cues
    }
}

/// A Cue due during a Phase on the Watch, dated on the wall clock, so its haptic lands on time rather than when an
/// update happens to arrive.
public nonisolated struct WatchCue: Codable, Hashable, Sendable {
    public let cue: Cue
    public let date: Date

    public init(cue: Cue, date: Date) {
        self.cue = cue
        self.date = date
    }
}

nonisolated extension WatchPhase {
    /// What the secondary page's upper capsule asks: Pause while the Phase runs, Resume while it's Paused. It's there
    /// in every Workout Type, because Open Rounds' capsule is Done.
    public var pauseOrResume: WatchCommand {
        pausedAt == nil ? .pause : .resume
    }

    /// The time the Watch shows at `date`, as `00:00`, rounded as on the iPhone's ring: counting down, the time left
    /// rounds up and holds at `00:00` past the end until the next update. Counting up, the time elapsed rounds down
    /// and keeps counting past any end. A Paused Phase holds at `pausedAt`.
    public func time(at date: Date) -> String {
        countsUp ? elapsed(at: date).clockText(rounding: .down) : timeLeft(at: date).clockText
    }

    /// What VoiceOver says for the time, such as "8 seconds left" or "4 seconds elapsed".
    public func spokenTime(at date: Date) -> String {
        countsUp
            ? "\(elapsed(at: date).spokenText(rounding: .down)) elapsed"
            : "\(timeLeft(at: date).spokenText(rounding: .up)) left"
    }

    /// How much of the bar is drawn at `date`, from 0 to 1. Counting down it empties. Counting up it fills, and stays
    /// full past the end. An open Phase has no length to fill towards, so it draws none.
    public func fill(at date: Date) -> Double {
        guard let end else { return 0 }
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return 0 }
        let fractionLeft = min(1, max(0, end.timeIntervalSince(pausedAt ?? date) / length))
        return countsUp ? 1 - fractionLeft : fractionLeft
    }

    private func elapsed(at date: Date) -> Duration {
        .seconds(max(0, (pausedAt ?? date).timeIntervalSince(start)))
    }

    private func timeLeft(at date: Date) -> Duration {
        guard let end else { return .zero }
        return .seconds(max(0, end.timeIntervalSince(pausedAt ?? date)))
    }
}

extension RunningDisplay {
    /// The Watch's state at `now`, which reads `date` on the wall clock. The dates are placed as for the Live
    /// Activity, from the time left or elapsed at `now`.
    public nonisolated func watchState(at now: Instant, date: Date) -> WatchState {
        guard let phase = snapshot.phase else { return .ended(completion) }
        let (start, end) = dates(of: phase, at: now, date: date)
        return .phase(
            WatchPhase(
                kind: phase.kind,
                round: phase.round,
                start: start,
                end: end,
                pausedAt: snapshot.isPaused ? date : nil,
                countsUp: countsUp,
                line: line,
                capsule: capsule,
                cues: snapshot.cues.map { cue in
                    WatchCue(cue: cue.cue, date: date.addingTimeInterval(now.duration(to: cue.due) / .seconds(1)))
                }
            )
        )
    }

    /// Done while the running screen's Done is enabled, and dimmed in Open Rounds otherwise. Pause, or Resume while
    /// Paused, in Intervals and in a Stopwatch up to its set length.
    nonisolated var capsule: WatchPhase.Capsule {
        if doneButton == .enabled { return .done }
        if workoutType == .openRounds { return .doneDimmed }
        return snapshot.isPaused ? .resume : .pause
    }
}
