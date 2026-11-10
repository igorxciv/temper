import Foundation
import Testing

@testable import TemperCore

/// The mirrored session carries at most 100 KB per 10 s, and nothing throttles what the iPhone sends. Only `end` grows
/// with the Workout. An update stays small however long the Workout runs.
nonisolated struct MessageToWatchSizeTests {
    private typealias Instant = ManualClock.Instant

    /// 200 Rounds of Open Rounds, each Work ended by hand at an uneven time, then a Rest, with a Pause in every Work,
    /// on a real wall clock, so each date encodes at full length.
    private var longOpenRounds: HealthRecord {
        var phases: [WorkoutRecord<Instant>.RecordedPhase] = []
        var pauses: [Range<Instant>] = []
        var time = Duration.zero
        for round in 1...200 {
            let work = Instant(offset: time)
            pauses.append(work.advanced(by: .seconds(10.123_457))..<work.advanced(by: .seconds(25.987_654)))
            let rest = work.advanced(by: .seconds(97.314_159))
            let next = rest.advanced(by: .seconds(60))
            phases.append(.init(kind: .work, round: round, start: work, end: rest))
            phases.append(.init(kind: .rest, round: round, start: rest, end: next))
            time = Instant(offset: .zero).duration(to: next)
        }
        let record = WorkoutRecord(
            start: Instant(offset: .zero), end: Instant(offset: time), pauses: pauses, phases: phases)
        return HealthRecord(
            record, of: .openRounds, workoutID: UUID(), attempt: 1,
            anchor: ClockAnchor(
                instant: Instant(offset: .zero), date: Date(timeIntervalSince1970: 1_794_321_987.654_321))
        )!
    }

    @Test func `The end of a 200-Round Open Rounds encodes well under the session's 100 KB`() throws {
        let size = try MessageToWatch.end(longOpenRounds).json().count

        #expect(size < 50_000)
    }

    /// The longest update: an Open Rounds Rest deep into a long Workout, with its full line and both Cues to come, on a
    /// real wall clock, built the way the iPhone builds it.
    @Test func `An update stays under 1 KB`() throws {
        let rest = Phase(kind: .rest, duration: .seconds(60), round: 200)
        let cues = [
            WorkoutSnapshot<Instant>.TimedCue(cue: .tenSeconds, due: Instant(offset: .seconds(36_050))),
            WorkoutSnapshot<Instant>.TimedCue(cue: .work, due: Instant(offset: .seconds(36_060))),
        ]
        let snapshot = WorkoutSnapshot(
            progress: .running(phase: rest, endsAt: Instant(offset: .seconds(36_060))), rounds: nil,
            previousOpenPhaseTime: .seconds(5_999.987_654), cues: cues)
        let display = RunningDisplay(
            workoutType: .openRounds,
            workout: WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch), snapshot: snapshot)
        let state = display.watchState(
            at: Instant(offset: .seconds(36_000.123_457)), date: Date(timeIntervalSince1970: 1_794_321_987.654_321))

        let size = try MessageToWatch.update(state).json().count

        #expect(size < 1_024)
    }
}
