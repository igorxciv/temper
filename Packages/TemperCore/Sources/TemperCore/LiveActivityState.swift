import Foundation

/// What the Live Activity shows at one snapshot. It appears on the Lock Screen, in the Dynamic Island and in the
/// Apple Watch Smart Stack.
///
/// The system draws a Phase's time from its dates, so the app changes the Live Activity only when the snapshot
/// changes, never on a tick. Its time uses the system's rounding, which can differ from the ring's by a second.
public nonisolated enum LiveActivityState: Codable, Hashable, Sendable {
    case phase(LivePhase)
    /// The Workout has finished, or Open Rounds has been Stopped. The total is the Workout record's active time as
    /// `00:00`, rounding down, and what VoiceOver says for it. For a finished Intervals that's its total length, and
    /// for a Stopwatch it's the time up to Done. Both are optional only so a state stored by an earlier build still
    /// decodes.
    case complete(total: String?, spokenTotal: String?)
}

/// A Phase on the Live Activity, running or Paused.
public nonisolated struct LivePhase: Codable, Hashable, Sendable {
    /// The Live Activity's one button. Its Workout Type isn't on the Live Activity, so the state names the button.
    public enum Button: String, Codable, Hashable, Sendable {
        case pause
        case resume
        /// Ends a running open Work, or a running Stopwatch Work past its set length.
        case done
    }

    public let kind: Phase.Kind
    /// When the Phase would have started if it ran without a Pause up to the snapshot.
    public let start: Date
    /// When the Phase would end if it ran without a Pause from the snapshot on, or `nil` for an open Phase, which
    /// ends only at Done. For a Stopwatch's Work it's when the Work reaches its set length.
    public let end: Date?
    /// The time at which a Paused Phase is held, or `nil` while it runs.
    public let pausedAt: Date?
    /// True during a Stopwatch's Work and an open Phase, which count up from `start`.
    public let countsUp: Bool
    /// The line under the time, the same as under the ring, and what VoiceOver says for it.
    public let line: String
    public let spokenLine: String
    /// Pause or Resume in Intervals, and in a Stopwatch up to its set length. Done in a running open Work and a
    /// running Stopwatch Work past its set length. `nil` in an Open Rounds Rest or while it's Paused, since Open
    /// Rounds keeps Pause in the app.
    public let button: Button?
    /// True for a Stopwatch's Work, whose time keeps counting past `end` until Done while its bar stays full. It's
    /// optional only so a state stored by an earlier build still decodes.
    public var countsPastEnd: Bool? = nil

    public var isPaused: Bool {
        pausedAt != nil
    }

    /// False for an open Phase, which has no length for a bar to fill or empty, the same as its empty ring.
    public var hasBar: Bool {
        end != nil
    }

    /// The range the system counts the time over: from `start` to `end`, or, for an open Phase and a Phase that
    /// counts past its end, from `start` with no end in sight, so it counts up for as long as it runs.
    public var interval: ClosedRange<Date> {
        start...(countsPastEnd == true ? .distantFuture : end ?? .distantFuture)
    }

    /// The range the system fills or empties the bar over, which stays full once a Phase counts past its end.
    public var barInterval: ClosedRange<Date> {
        start...(end ?? .distantFuture)
    }

    /// How much of a Paused Phase's bar is drawn, the same as its ring. A running bar is drawn by the system. An
    /// open Phase has no length to fill towards, so it draws none.
    public var pausedFill: Double {
        guard let pausedAt, let end else { return 0 }
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return 0 }
        let fractionLeft = min(1, max(0, end.timeIntervalSince(pausedAt) / length))
        return countsUp ? 1 - fractionLeft : fractionLeft
    }
}

extension RunningDisplay {
    /// The Live Activity's state at `now`, which reads `date` on the wall clock, or `nil` when a Stop should end
    /// it at once, as in Intervals and Stopwatch. An ended Workout with a complete screen shows the complete state.
    ///
    /// The engine's clock keeps counting while the iPhone sleeps, and the wall clock can be changed, so the dates
    /// are worked out from the time left, or the time elapsed in an open Phase, at `now` rather than kept from
    /// Start.
    public nonisolated func liveActivityState(at now: Instant, date: Date) -> LiveActivityState? {
        switch snapshot.progress {
        case .running(let phase, _), .runningOpen(let phase, _), .paused(let phase, _), .pausedOpen(let phase, _):
            let (start, end) = dates(of: phase, at: now, date: date)
            let (text, spoken) = liveLineText
            return .phase(
                LivePhase(
                    kind: phase.kind,
                    start: start,
                    end: end,
                    pausedAt: snapshot.isPaused ? date : nil,
                    countsUp: countsUp,
                    line: text,
                    spokenLine: spoken,
                    button: liveButton,
                    countsPastEnd: phase.runsPastSetLength
                )
            )
        case .finished(let record), .stopped(let record):
            return completion == nil ? nil : complete(record)
        }
    }

    /// When `phase` would have started had it run without a Pause up to `now`, and when it would end, or reach the set
    /// length it runs past, if it runs without a Pause from `now` on. An open Phase has no end.
    nonisolated func dates(of phase: Phase, at now: Instant, date: Date) -> (start: Date, end: Date?) {
        let start = date.addingTimeInterval(-(snapshot.elapsed(at: now) / .seconds(1)))
        let end: Date? =
            switch phase.length {
            case .set: date.addingTimeInterval(snapshot.timeLeft(at: now) / .seconds(1))
            case .runsPast(let length): start.addingTimeInterval(length / .seconds(1))
            case .open: nil
            }
        return (start, end)
    }

    /// Done while the running screen's Done is enabled. Otherwise nothing in Open Rounds, which keeps Pause in the
    /// app, and Pause, or Resume while Paused, in Intervals and Stopwatch.
    private nonisolated var liveButton: LivePhase.Button? {
        if doneButton == .enabled { return .done }
        if workoutType == .openRounds { return nil }
        return snapshot.isPaused ? .resume : .pause
    }

    private nonisolated func complete(_ record: WorkoutRecord<Instant>) -> LiveActivityState {
        .complete(
            total: record.activeTime.clockText(rounding: .down),
            spokenTotal: record.activeTime.spokenText(rounding: .down)
        )
    }

    /// The running screen's line, except that Open Rounds shows only the Round in both Phases, since its Rest line
    /// is too long for the Live Activity.
    private nonisolated var liveLineText: (text: String, spoken: String) {
        if workoutType == .openRounds, !snapshot.isPaused, let round = snapshot.phase?.round {
            return ("Round \(round)", "Round \(round)")
        }
        return lineText
    }

    /// The line under the ring on one line of text, with its caption on the same side as on the running screen.
    private nonisolated var lineText: (text: String, spoken: String) {
        switch line {
        case .value(let value, .before(let caption), let spoken): ("\(caption) \(value)", spoken)
        case .value(let value, .after(let caption), let spoken): ("\(value) \(caption)", spoken)
        case .paused: ("Paused", "Paused")
        case nil: ("", "")
        }
    }
}
