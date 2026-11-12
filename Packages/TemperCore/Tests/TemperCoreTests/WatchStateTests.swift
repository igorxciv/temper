import Foundation
import Testing

@testable import TemperCore

/// What the iPhone sends the Watch to draw: the running screen's Phase, dated, or the complete screen.
nonisolated struct WatchStateTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let intervals = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)
    /// Prepare 00:10, then Work 10:00.
    private let stopwatch = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
    private let openRounds = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)

    private let work = Phase(kind: .work, duration: .seconds(40), round: 3)
    private let stopwatchWork = Phase(kind: .work, length: .runsPast(.seconds(600)))
    private let openWork = Phase(kind: .work, length: .open, round: 3)
    private let rest = Phase(kind: .rest, duration: .seconds(60), round: 3)

    /// The wall clock at the moment the state is worked out.
    private let date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func intervals(_ progress: Snapshot.Progress) -> Display {
        Display(workout: intervals, snapshot: Snapshot(progress: progress, rounds: 8))
    }

    private func stopwatch(_ progress: Snapshot.Progress) -> Display {
        Display(workout: stopwatch, snapshot: Snapshot(progress: progress, rounds: 0))
    }

    private func openRounds(_ progress: Snapshot.Progress, workTime: Duration? = nil) -> Display {
        let snapshot = Snapshot(progress: progress, rounds: nil, previousOpenPhaseTime: workTime)
        return Display(workout: openRounds, snapshot: snapshot)
    }

    private func watchPhase(_ state: WatchState) -> WatchPhase? {
        if case .phase(let phase) = state { phase } else { nil }
    }

    @Test func `A running Intervals Work is dated by its time left, under its Round line, with Pause`() throws {
        let display = intervals(.running(phase: work, endsAt: at(100)))

        let phase = try #require(watchPhase(display.watchState(at: at(92.5), date: date)))

        #expect(phase.kind == .work)
        #expect(phase.round == 3)
        #expect(phase.start == date.addingTimeInterval(-32.5))
        #expect(phase.end == date.addingTimeInterval(7.5))
        #expect(phase.pausedAt == nil)
        #expect(!phase.countsUp)
        #expect(phase.line == .value("3", caption: .after("of 8"), spoken: "Round 3 of 8"))
        #expect(phase.capsule == .pause)
    }

    @Test func `An Open Rounds Rest carries "10 seconds" and then Work, dated on the wall clock`() throws {
        let cues = [Snapshot.TimedCue(cue: .tenSeconds, due: at(150)), Snapshot.TimedCue(cue: .work, due: at(160))]
        let snapshot = Snapshot(
            progress: .running(phase: rest, endsAt: at(160)), rounds: nil, previousOpenPhaseTime: .seconds(90),
            cues: cues)
        let display = Display(workout: openRounds, snapshot: snapshot)

        let phase = try #require(watchPhase(display.watchState(at: at(102.5), date: date)))

        #expect(
            phase.cues == [
                WatchCue(cue: .tenSeconds, date: date.addingTimeInterval(47.5)),
                WatchCue(cue: .work, date: date.addingTimeInterval(57.5)),
            ])
    }

    @Test func `A Phase with no Cues to come, such as a Paused one, carries none`() throws {
        let display = intervals(.paused(phase: work, timeLeft: .seconds(10)))

        #expect(try #require(watchPhase(display.watchState(at: at(500), date: date))).cues == [])
    }

    @Test func `A Paused Phase is held now, shows Paused, and offers Resume`() throws {
        let display = intervals(.paused(phase: work, timeLeft: .seconds(10)))

        let phase = try #require(watchPhase(display.watchState(at: at(500), date: date)))

        #expect(phase.pausedAt == date)
        #expect(phase.start == date.addingTimeInterval(-30))
        #expect(phase.end == date.addingTimeInterval(10))
        #expect(phase.line == .paused)
        #expect(phase.capsule == .resume)
    }

    @Test func `An Open Rounds Work counts up with no end, under its Round, with Done`() throws {
        let display = openRounds(.runningOpen(phase: openWork, startedAt: at(100)))

        let phase = try #require(watchPhase(display.watchState(at: at(130), date: date)))

        #expect(phase.start == date.addingTimeInterval(-30))
        #expect(phase.end == nil)
        #expect(phase.countsUp)
        #expect(phase.line == .value("3", caption: .before("Round"), spoken: "Round 3"))
        #expect(phase.capsule == .done)
    }

    /// The Live Activity shortens this line to the Round alone, but the Watch has room for the running screen's.
    @Test func `An Open Rounds Rest carries the running screen's full line, with Done dimmed`() throws {
        let display = openRounds(.running(phase: rest, endsAt: at(160)), workTime: .seconds(102))

        let phase = try #require(watchPhase(display.watchState(at: at(150), date: date)))

        #expect(phase.end == date.addingTimeInterval(10))
        #expect(!phase.countsUp)
        #expect(
            phase.line
                == .value("1:42", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 1 minute 42 seconds")
        )
        #expect(phase.capsule == .doneDimmed)
    }

    @Test func `A Paused Open Rounds Work dims its Done`() throws {
        let display = openRounds(.pausedOpen(phase: openWork, elapsed: .seconds(42)))

        let phase = try #require(watchPhase(display.watchState(at: at(500), date: date)))

        #expect(phase.capsule == .doneDimmed)
        #expect(phase.line == .paused)
    }

    @Test func `A Stopwatch offers Pause up to its set length, then Done, ending where it reaches the length`() throws {
        let before = try #require(
            watchPhase(stopwatch(.running(phase: stopwatchWork, endsAt: at(610))).watchState(at: at(460), date: date)))
        let past = try #require(
            watchPhase(
                stopwatch(.runningOpen(phase: stopwatchWork, startedAt: at(10))).watchState(at: at(882.5), date: date)))

        #expect(before.capsule == .pause)
        #expect(before.end == date.addingTimeInterval(150))
        #expect(before.round == nil)
        #expect(past.capsule == .done)
        #expect(past.countsUp)
        #expect(past.start == date.addingTimeInterval(-872.5))
        #expect(past.end == date.addingTimeInterval(-272.5))
        #expect(past.line == .value("10:00", caption: .before("of"), spoken: "of 10 minutes"))
    }

    @Test func `A finished Workout ends on the complete screen with its total`() {
        #expect(intervals(.finished(.lasting(530))).watchState(at: at(0), date: date) == .ended(.total(.seconds(530))))
    }

    @Test func `A Stop in Intervals or Stopwatch ends with no complete screen`() {
        #expect(intervals(.stopped(.lasting(100))).watchState(at: at(0), date: date) == .ended(nil))
        #expect(stopwatch(.stopped(.lasting(100))).watchState(at: at(0), date: date) == .ended(nil))
    }

    @Test func `A Stopped Open Rounds ends on its Rounds complete screen`() {
        let record = WorkoutRecord(
            start: at(0), end: at(250), pauses: [],
            phases: [
                .init(kind: .work, round: 1, start: at(0), end: at(102)),
                .init(kind: .rest, round: 1, start: at(102), end: at(162)),
                .init(kind: .work, round: 2, start: at(162), end: at(250)),
            ])

        let state = openRounds(.stopped(record)).watchState(at: at(0), date: date)

        guard case .ended(.rounds(let summary)) = state else {
            Issue.record("Expected the Rounds complete screen, got \(state)")
            return
        }
        #expect(summary.total == "04:10")
        #expect(summary.countText == "2 Rounds")
        #expect(summary.rows.map(\.time) == ["1:42", "1:28"])
    }

    @Test(arguments: [
        WatchState.phase(
            WatchPhase(
                kind: .rest, round: 3, start: Date(timeIntervalSinceReferenceDate: 10),
                end: Date(timeIntervalSinceReferenceDate: 70), pausedAt: nil, countsUp: false,
                line: .value("1:42", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 1 minute 42 seconds"),
                capsule: .doneDimmed)),
        WatchState.ended(nil),
        WatchState.ended(.total(.milliseconds(530_250))),
    ])
    func `A state survives encoding, as it crosses to the Watch`(state: WatchState) throws {
        let decoded = try JSONDecoder().decode(WatchState.self, from: JSONEncoder().encode(state))

        #expect(decoded == state)
    }
}
