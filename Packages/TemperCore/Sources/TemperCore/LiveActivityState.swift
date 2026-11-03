import Foundation

/// What the Live Activity shows at one snapshot. It appears on the Lock Screen, in the Dynamic Island and in the
/// Apple Watch Smart Stack.
///
/// The system draws a Phase's time from its dates, so the app changes the Live Activity only when the snapshot
/// changes, never on a tick. Its time uses the system's rounding, which can differ from the ring's by a second.
public nonisolated enum LiveActivityState: Codable, Hashable, Sendable {
    case phase(LivePhase)
    /// The Workout has finished. The total is its length as `00:00`, and what VoiceOver says for it.
    case complete(total: String, spokenTotal: String)
}

/// A Phase on the Live Activity, running or Paused.
public nonisolated struct LivePhase: Codable, Hashable, Sendable {
    public let kind: Phase.Kind
    /// When the Phase would start and end if it ran without a Pause from the snapshot on.
    public let interval: ClosedRange<Date>
    /// The time at which a Paused Phase is held, or `nil` while it runs.
    public let pausedAt: Date?
    /// True during a Stopwatch's Work, which counts up from the start of `interval`.
    public let countsUp: Bool
    /// The line under the time, the same as under the ring, and what VoiceOver says for it.
    public let line: String
    public let spokenLine: String

    public var isPaused: Bool {
        pausedAt != nil
    }

    /// How much of a Paused Phase's bar is drawn, the same as its ring. A running bar is drawn by the system.
    public var pausedFill: Double {
        let length = interval.upperBound.timeIntervalSince(interval.lowerBound)
        guard let pausedAt, length > 0 else { return 0 }
        let fractionLeft = min(1, max(0, interval.upperBound.timeIntervalSince(pausedAt) / length))
        return countsUp ? 1 - fractionLeft : fractionLeft
    }
}

extension RunningDisplay {
    /// The Live Activity's state at `now`, which reads `date` on the wall clock, or `nil` once the Workout stops.
    ///
    /// The engine's clock keeps counting while the iPhone sleeps, and the wall clock can be changed, so the dates
    /// are worked out from the time left at `now` rather than kept from Start.
    public nonisolated func liveActivityState(at now: Instant, date: Date) -> LiveActivityState? {
        switch snapshot.progress {
        case .running(let phase, _), .paused(let phase, _):
            let end = date.addingTimeInterval(snapshot.timeLeft(at: now) / .seconds(1))
            let start = end.addingTimeInterval(-(phase.duration / .seconds(1)))
            let (text, spoken) = lineText
            return .phase(
                LivePhase(
                    kind: phase.kind,
                    interval: start...end,
                    pausedAt: snapshot.isPaused ? date : nil,
                    countsUp: countsUp,
                    line: text,
                    spokenLine: spoken
                )
            )
        case .finished:
            let total = workout.totalDuration
            return .complete(total: total.clockText, spokenTotal: total.spokenText(rounding: .up))
        case .stopped:
            return nil
        }
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
