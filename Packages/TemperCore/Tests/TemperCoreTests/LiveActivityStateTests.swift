import Foundation
import Testing

@testable import TemperCore

nonisolated struct LiveActivityStateTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let intervals = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)
    /// Prepare 00:10, then Work 10:00.
    private let stopwatch = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)

    private let work = Phase(kind: .work, duration: .seconds(40), round: 3)
    private let stopwatchWork = Phase(kind: .work, duration: .seconds(600))

    /// The wall clock at the moment the state is worked out.
    private let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func intervals(_ progress: Snapshot.Progress) -> Display {
        Display(workoutType: .intervals, workout: intervals, snapshot: Snapshot(progress: progress, rounds: 8))
    }

    private func stopwatch(_ progress: Snapshot.Progress) -> Display {
        Display(workoutType: .stopwatch, workout: stopwatch, snapshot: Snapshot(progress: progress, rounds: 0))
    }

    private func livePhase(_ state: LiveActivityState?) -> LivePhase? {
        if case .phase(let phase) = state { phase } else { nil }
    }

    @Test func `A running Phase spans its whole length, placed by the time left`() throws {
        let display = intervals(.running(phase: work, endsAt: at(100)))

        let phase = try #require(livePhase(display.liveActivityState(at: at(92.5), date: date)))

        #expect(phase.kind == .work)
        #expect(phase.interval == date.addingTimeInterval(-32.5)...date.addingTimeInterval(7.5))
        #expect(phase.pausedAt == nil)
        #expect(!phase.isPaused)
        #expect(!phase.countsUp)
        #expect(phase.hasBar)
    }

    @Test func `A Phase past its end, before the next snapshot, ends now`() throws {
        let display = intervals(.running(phase: work, endsAt: at(100)))

        let phase = try #require(livePhase(display.liveActivityState(at: at(100.2), date: date)))

        #expect(phase.interval.upperBound == date)
    }

    @Test func `A Paused Phase is held now, with the time it had left`() throws {
        let display = intervals(.paused(phase: work, timeLeft: .seconds(10)))

        let phase = try #require(livePhase(display.liveActivityState(at: at(500), date: date)))

        #expect(phase.pausedAt == date)
        #expect(phase.interval.upperBound == date.addingTimeInterval(10))
        #expect(phase.pausedFill == 0.25)
    }

    @Test func `A Paused Stopwatch fills its bar with the time elapsed`() throws {
        let display = stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(150)))

        let phase = try #require(livePhase(display.liveActivityState(at: at(0), date: date)))

        #expect(phase.countsUp)
        #expect(phase.pausedFill == 0.75)
    }

    @Test func `The line is the running screen's line, caption on the same side`() throws {
        let round = try #require(
            livePhase(intervals(.running(phase: work, endsAt: at(100))).liveActivityState(at: at(90), date: date))
        )
        let length = try #require(
            livePhase(
                stopwatch(.running(phase: stopwatchWork, endsAt: at(610))).liveActivityState(at: at(20), date: date)
            )
        )
        let paused = try #require(
            livePhase(intervals(.paused(phase: work, timeLeft: .seconds(5))).liveActivityState(at: at(0), date: date))
        )

        #expect(round.line == "3 of 8")
        #expect(round.spokenLine == "Round 3 of 8")
        #expect(length.line == "of 10:00")
        #expect(paused.line == "Paused")
    }

    @Test func `Intervals and Stopwatch offer Pause while running and Resume while Paused`() throws {
        let running = try #require(
            livePhase(intervals(.running(phase: work, endsAt: at(100))).liveActivityState(at: at(90), date: date))
        )
        let paused = try #require(
            livePhase(
                stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(150))).liveActivityState(
                    at: at(0), date: date))
        )

        #expect(running.button == .pause)
        #expect(paused.button == .resume)
    }

    @Test func `A finished Workout shows its total length`() {
        let state = intervals(.finished(.lasting(530))).liveActivityState(at: at(0), date: date)

        #expect(state == .complete(total: "08:50", spokenTotal: "8 minutes 50 seconds"))
    }

    @Test func `A stopped Workout has no Live Activity`() {
        #expect(intervals(.stopped(.lasting(0))).liveActivityState(at: at(0), date: date) == nil)
    }

    @Test func `A stopped Stopwatch has no Live Activity`() {
        #expect(stopwatch(.stopped(.lasting(100))).liveActivityState(at: at(0), date: date) == nil)
    }

    @Test func `The state survives encoding, as the system stores it`() throws {
        let state = intervals(.paused(phase: work, timeLeft: .seconds(10))).liveActivityState(at: at(0), date: date)

        let decoded = try JSONDecoder().decode(LiveActivityState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
    }
}

/// Open Rounds on the Live Activity: an open Work counting up from its start, and a Rest counting down.
nonisolated struct LiveActivityStateOpenRoundsTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let openRounds = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)
    private let work = Phase(kind: .work, length: .open, round: 3)
    private let rest = Phase(kind: .rest, duration: .seconds(60), round: 3)
    private let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func state(_ progress: Snapshot.Progress, at now: Double, workTime: Duration? = nil) -> LiveActivityState? {
        let snapshot = Snapshot(progress: progress, rounds: nil, previousOpenPhaseTime: workTime)
        return Display(workoutType: .openRounds, workout: openRounds, snapshot: snapshot)
            .liveActivityState(at: at(now), date: date)
    }

    private func livePhase(_ state: LiveActivityState?) -> LivePhase? {
        if case .phase(let phase) = state { phase } else { nil }
    }

    @Test func `An open Work counts up from its start, with no end, under its Round`() throws {
        let phase = try #require(livePhase(state(.runningOpen(phase: work, startedAt: at(100)), at: 130)))

        #expect(phase.kind == .work)
        #expect(phase.start == date.addingTimeInterval(-30))
        #expect(phase.end == nil)
        #expect(phase.countsUp)
        #expect(!phase.hasBar)
        #expect(!phase.isPaused)
        #expect(phase.line == "Round 3")
        #expect(phase.spokenLine == "Round 3")
    }

    @Test func `A Paused open Work is held now, with no end and no bar`() throws {
        let phase = try #require(livePhase(state(.pausedOpen(phase: work, elapsed: .seconds(42)), at: 500)))

        #expect(phase.start == date.addingTimeInterval(-42))
        #expect(phase.end == nil)
        #expect(phase.pausedAt == date)
        #expect(phase.pausedFill == 0)
        #expect(!phase.hasBar)
        #expect(phase.line == "Paused")
    }

    @Test func `A Rest counts down to its end, with only its Round as the line`() throws {
        let phase = try #require(
            livePhase(state(.running(phase: rest, endsAt: at(160)), at: 150, workTime: .seconds(102))))

        #expect(phase.start == date.addingTimeInterval(-50))
        #expect(phase.end == date.addingTimeInterval(10))
        #expect(!phase.countsUp)
        #expect(phase.hasBar)
        #expect(phase.line == "Round 3")
        #expect(phase.spokenLine == "Round 3")
    }

    @Test func `A Paused Rest shows Paused`() throws {
        let phase = try #require(
            livePhase(state(.paused(phase: rest, timeLeft: .seconds(15)), at: 0, workTime: .seconds(102))))

        #expect(phase.line == "Paused")
        #expect(phase.pausedFill == 0.25)
    }

    @Test func `Only a running open Work offers Done, and Rest and Pause offer no button`() throws {
        let runningWork = try #require(livePhase(state(.runningOpen(phase: work, startedAt: at(100)), at: 130)))
        let pausedWork = try #require(livePhase(state(.pausedOpen(phase: work, elapsed: .seconds(42)), at: 500)))
        let runningRest = try #require(
            livePhase(state(.running(phase: rest, endsAt: at(160)), at: 150, workTime: .seconds(102))))
        let pausedRest = try #require(
            livePhase(state(.paused(phase: rest, timeLeft: .seconds(15)), at: 0, workTime: .seconds(102))))

        #expect(runningWork.button == .done)
        #expect(pausedWork.button == nil)
        #expect(runningRest.button == nil)
        #expect(pausedRest.button == nil)
    }

    @Test func `After a Stop it shows Workout complete with the active time, rounding down`() {
        #expect(
            state(.stopped(.lasting(1_390.8)), at: 0)
                == .complete(total: "23:10", spokenTotal: "23 minutes 10 seconds")
        )
    }

    @Test func `An open Work's state survives encoding, with no end`() throws {
        let state = state(.runningOpen(phase: work, startedAt: at(100)), at: 130)

        let decoded = try JSONDecoder().decode(LiveActivityState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
        #expect(livePhase(decoded)?.end == nil)
    }
}
