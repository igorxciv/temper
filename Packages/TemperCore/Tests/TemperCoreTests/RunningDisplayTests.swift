import Testing

@testable import TemperCore

nonisolated struct RunningDisplayTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let intervals = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)
    /// Prepare 00:10, then Work 10:00 from 10 s to 610 s.
    private let stopwatch = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)

    private let prepare = Phase(kind: .prepare, duration: .seconds(10))
    private let work = Phase(kind: .work, duration: .seconds(40), round: 3)
    private let rest = Phase(kind: .rest, duration: .seconds(20), round: 3)
    private let cooldown = Phase(kind: .cooldown, duration: .seconds(60))
    private let stopwatchWork = Phase(kind: .work, duration: .seconds(600))

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func intervals(_ progress: Snapshot.Progress, rounds: Int = 8) -> Display {
        Display(workoutType: .intervals, workout: intervals, snapshot: Snapshot(progress: progress, rounds: rounds))
    }

    private func stopwatch(_ progress: Snapshot.Progress) -> Display {
        Display(workoutType: .stopwatch, workout: stopwatch, snapshot: Snapshot(progress: progress, rounds: 0))
    }

    private func running(_ phase: Phase, endsAt end: Double) -> Snapshot.Progress {
        .running(phase: phase, endsAt: at(end))
    }

    // MARK: Which way the time counts

    @Test func `Only a Stopwatch's Work counts up, Paused or not`() {
        #expect(stopwatch(running(stopwatchWork, endsAt: 610)).countsUp)
        #expect(stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(5))).countsUp)
        #expect(!stopwatch(running(prepare, endsAt: 10)).countsUp)
        #expect(!stopwatch(.finished(.lasting(0))).countsUp)
        #expect(!intervals(running(work, endsAt: 100)).countsUp)
    }

    @Test func `Intervals and Stopwatch have no Done button`() {
        #expect(intervals(running(work, endsAt: 100)).doneButton == nil)
        #expect(stopwatch(running(stopwatchWork, endsAt: 610)).doneButton == nil)
        #expect(stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(5))).doneButton == nil)
    }

    // MARK: Counting down

    @Test func `Counting down shows the time left, rounding up`() {
        let ring = intervals(running(work, endsAt: 100)).ring(at: at(92.8))

        #expect(ring.time == "00:08")
        #expect(ring.spokenTime == "8 seconds left")
    }

    @Test func `Counting down, the ring is full as a Phase starts and empties`() {
        let display = intervals(running(work, endsAt: 100))

        #expect(display.ring(at: at(60)).fill == 1)
        #expect(display.ring(at: at(90)).fill == 0.25)
        #expect(display.ring(at: at(100)).fill == 0)
    }

    @Test func `A Stopwatch's Prepare counts down`() {
        let ring = stopwatch(running(prepare, endsAt: 10)).ring(at: at(0))

        #expect(ring.time == "00:10")
        #expect(ring.spokenTime == "10 seconds left")
        #expect(ring.fill == 1)
    }

    @Test func `Counting down reads in minutes and seconds`() {
        let ring = intervals(running(cooldown, endsAt: 600)).ring(at: at(304))

        #expect(ring.time == "04:56")
        #expect(ring.spokenTime == "4 minutes 56 seconds left")
    }

    @Test func `An ended Workout's ring is empty, with no time left`() {
        let ring = intervals(.finished(.lasting(0))).ring(at: at(1))

        #expect(ring == .init(time: "00:00", spokenTime: "0 seconds left", fill: 0))
    }

    // MARK: Counting up

    @Test func `A Stopwatch's Work reads 00:00 as it starts, with the ring empty`() {
        let ring = stopwatch(running(stopwatchWork, endsAt: 610)).ring(at: at(10))

        #expect(ring == .init(time: "00:00", spokenTime: "0 seconds elapsed", fill: 0))
    }

    @Test func `At the same instant, counting up rounds down and counting down rounds up`() {
        let up = stopwatch(running(stopwatchWork, endsAt: 610)).ring(at: at(14.5))
        let down = intervals(running(stopwatchWork, endsAt: 610)).ring(at: at(14.5))

        #expect(up.time == "00:04")
        #expect(up.spokenTime == "4 seconds elapsed")
        #expect(down.time == "09:56")
        #expect(down.spokenTime == "9 minutes 56 seconds left")
    }

    @Test func `Counting up, the ring fills`() {
        #expect(stopwatch(running(stopwatchWork, endsAt: 610)).ring(at: at(160)).fill == 0.25)
    }

    @Test func `The full length shows only as Work ends`() {
        let display = stopwatch(running(stopwatchWork, endsAt: 610))

        #expect(display.ring(at: at(609.999)).time == "09:59")
        #expect(display.ring(at: at(610)).time == "10:00")
        #expect(display.ring(at: at(610)).fill == 1)
    }

    @Test(arguments: [610.001, 5_000.0])
    func `The time elapsed holds at the length until the next snapshot`(now: Double) {
        let ring = stopwatch(running(stopwatchWork, endsAt: 610)).ring(at: at(now))

        #expect(ring == .init(time: "10:00", spokenTime: "10 minutes elapsed", fill: 1))
    }

    @Test func `Counting up holds its place during a Pause`() {
        let ring = stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(450))).ring(at: at(9_000))

        #expect(ring == .init(time: "02:30", spokenTime: "2 minutes 30 seconds elapsed", fill: 0.25))
    }

    // MARK: The line in Intervals

    @Test func `Prepare shows the Rounds ahead`() {
        #expect(
            intervals(running(prepare, endsAt: 10)).line
                == .value("8", caption: .after("Rounds"), spoken: "8 Rounds")
        )
    }

    @Test func `Prepare before a single Round uses the singular`() {
        #expect(
            intervals(running(prepare, endsAt: 10), rounds: 1).line
                == .value("1", caption: .after("Round"), spoken: "1 Round")
        )
    }

    @Test func `Work and Rest show their Round and the total`() {
        let expected = RingLine.value("3", caption: .after("of 8"), spoken: "Round 3 of 8")

        #expect(intervals(running(work, endsAt: 100)).line == expected)
        #expect(intervals(running(rest, endsAt: 100)).line == expected)
    }

    @Test func `Cooldown shows the last Round and speaks the total`() {
        #expect(
            intervals(running(cooldown, endsAt: 100)).line == .value("8", caption: .after("of 8"), spoken: "8 Rounds")
        )
    }

    @Test func `Cooldown after a single Round speaks the singular`() {
        #expect(
            intervals(running(cooldown, endsAt: 100), rounds: 1).line
                == .value("1", caption: .after("of 1"), spoken: "1 Round")
        )
    }

    // MARK: The line in a Stopwatch

    @Test func `A Stopwatch's Prepare shows the length to come`() {
        #expect(
            stopwatch(running(prepare, endsAt: 10)).line
                == .value("10:00", caption: .after("Stopwatch"), spoken: "Stopwatch, 10 minutes")
        )
    }

    @Test func `A Stopwatch's Work shows the length it counts up to`() {
        #expect(
            stopwatch(running(stopwatchWork, endsAt: 610)).line
                == .value("10:00", caption: .before("of"), spoken: "of 10 minutes")
        )
    }

    @Test func `A Stopwatch with no Prepare shows its length from the start`() {
        let work = Phase(kind: .work, duration: .seconds(65))
        let display = Display(
            workoutType: .stopwatch,
            workout: Workout(phases: [work]),
            snapshot: Snapshot(progress: running(work, endsAt: 65), rounds: 0)
        )

        #expect(display.line == .value("01:05", caption: .before("of"), spoken: "of 1 minute 5 seconds"))
    }

    // MARK: Paused and ended

    @Test(arguments: [Phase.Kind.prepare, .work, .rest, .cooldown])
    func `A Pause in any Intervals Phase shows Paused`(kind: Phase.Kind) {
        let phase = Phase(kind: kind, duration: .seconds(10), round: kind == .work ? 1 : nil)

        #expect(intervals(.paused(phase: phase, timeLeft: .seconds(1))).line == .paused)
    }

    @Test func `A Pause in either Stopwatch Phase shows Paused`() {
        #expect(stopwatch(.paused(phase: prepare, timeLeft: .seconds(1))).line == .paused)
        #expect(stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(1))).line == .paused)
    }

    @Test(arguments: [WorkoutType.intervals, .stopwatch])
    func `An ended Workout has no line`(type: WorkoutType) {
        let workout = type == .intervals ? intervals : stopwatch
        let display = Display(
            workoutType: type, workout: workout, snapshot: Snapshot(progress: .finished(.lasting(0)), rounds: 8))

        #expect(display.line == nil)
    }

    // MARK: Complete screen

    @Test(arguments: [WorkoutType.intervals, .stopwatch])
    func `A finished Workout opens the complete screen with its total length`(type: WorkoutType) {
        let workout = type == .intervals ? intervals : stopwatch
        let display = Display(
            workoutType: type, workout: workout, snapshot: Snapshot(progress: .finished(.lasting(0)), rounds: 8))

        #expect(display.completion == .total(workout.totalDuration))
    }

    @Test func `A Stop in Intervals and Stopwatch returns to setup, with no complete screen`() {
        #expect(intervals(.stopped(.lasting(100))).completion == nil)
        #expect(stopwatch(.stopped(.lasting(100))).completion == nil)
    }

    @Test func `A running Workout has no complete screen`() {
        #expect(intervals(running(work, endsAt: 100)).completion == nil)
        #expect(stopwatch(.paused(phase: stopwatchWork, timeLeft: .seconds(5))).completion == nil)
    }
}

/// Open Rounds: an open Work counting up, then a Rest counting down, Round after Round.
nonisolated struct RunningDisplayOpenRoundsTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let openRounds = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)
    private let work = Phase(kind: .work, length: .open, round: 3)
    private let rest = Phase(kind: .rest, duration: .seconds(60), round: 3)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func display(_ progress: Snapshot.Progress, workTime: Duration? = nil) -> Display {
        Display(
            workoutType: .openRounds,
            workout: openRounds,
            snapshot: Snapshot(progress: progress, rounds: nil, previousOpenPhaseTime: workTime)
        )
    }

    // MARK: Open Work

    @Test func `An open Work counts up from its start, rounding down`() {
        let display = display(.runningOpen(phase: work, startedAt: at(100)))

        let ring = display.ring(at: at(164.9))

        #expect(display.countsUp)
        #expect(ring.time == "01:04")
        #expect(ring.spokenTime == "1 minute 4 seconds elapsed")
    }

    @Test func `An open Work reads 00:00 as it starts`() {
        #expect(display(.runningOpen(phase: work, startedAt: at(100))).ring(at: at(100.9)).time == "00:00")
    }

    @Test func `An open Work past an hour keeps counting in minutes`() {
        let ring = display(.runningOpen(phase: work, startedAt: at(0))).ring(at: at(4_335.5))

        #expect(ring.time == "72:15")
        #expect(ring.spokenTime == "72 minutes 15 seconds elapsed")
    }

    @Test func `An open Work draws only the empty track, running or Paused`() {
        #expect(display(.runningOpen(phase: work, startedAt: at(0))).ring(at: at(30)).fill == 0)
        #expect(display(.pausedOpen(phase: work, elapsed: .seconds(30))).ring(at: at(90)).fill == 0)
    }

    @Test func `A Paused open Work holds its time`() {
        let ring = display(.pausedOpen(phase: work, elapsed: .milliseconds(102_700))).ring(at: at(9_000))

        #expect(ring.time == "01:42")
        #expect(ring.spokenTime == "1 minute 42 seconds elapsed")
    }

    @Test func `An open Work's line is its Round`() {
        #expect(
            display(.runningOpen(phase: work, startedAt: at(0))).line
                == .value("3", caption: .before("Round"), spoken: "Round 3")
        )
    }

    /// With a Rest of zero, the next Work starts at Done and carries the Work time just ended, which only a Rest
    /// shows.
    @Test func `An open Work after a Rest of zero shows only its Round`() {
        #expect(
            display(.runningOpen(phase: work, startedAt: at(0)), workTime: .seconds(40)).line
                == .value("3", caption: .before("Round"), spoken: "Round 3")
        )
    }

    // MARK: Rest

    @Test func `Rest counts down, rounding up, and empties the ring`() {
        let display = display(.running(phase: rest, endsAt: at(160)), workTime: .seconds(102))

        #expect(!display.countsUp)
        #expect(display.ring(at: at(151.2)).time == "00:09")
        #expect(display.ring(at: at(152)).spokenTime == "8 seconds left")
        #expect(display.ring(at: at(100)).fill == 1)
        #expect(display.ring(at: at(145)).fill == 0.25)
    }

    @Test func `Rest's line gives its Round and the Work time just ended, rounding down`() {
        let display = display(.running(phase: rest, endsAt: at(160)), workTime: .milliseconds(102_900))

        #expect(
            display.line
                == .value("1:42", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 1 minute 42 seconds")
        )
    }

    @Test func `A Work time past an hour reads in minutes on Rest's line`() {
        let display = display(.running(phase: rest, endsAt: at(160)), workTime: .seconds(4_335))

        #expect(
            display.line
                == .value(
                    "72:15", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 72 minutes 15 seconds")
        )
    }

    @Test func `A Pause in either Phase shows Paused`() {
        #expect(display(.pausedOpen(phase: work, elapsed: .seconds(5))).line == .paused)
        #expect(display(.paused(phase: rest, timeLeft: .seconds(5)), workTime: .seconds(40)).line == .paused)
    }

    @Test func `A stopped Open Rounds has no line`() {
        #expect(display(.stopped(.lasting(130))).line == nil)
    }

    @Test func `A Stop opens the Rounds complete screen for the record, even seconds after Start`() {
        let record = WorkoutRecord<ManualClock.Instant>.lasting(3)

        #expect(display(.stopped(record)).completion == .rounds(RoundsSummary(record: record)))
    }

    @Test func `A running Open Rounds has no complete screen`() {
        #expect(display(.runningOpen(phase: work, startedAt: at(0))).completion == nil)
        #expect(display(.paused(phase: rest, timeLeft: .seconds(5)), workTime: .seconds(40)).completion == nil)
    }

    // MARK: Done

    @Test func `Done is enabled only in a running open Work`() {
        #expect(display(.runningOpen(phase: work, startedAt: at(0))).doneButton == .enabled)
    }

    /// It stays in place, so nothing moves under the owner's thumb.
    @Test func `Done stays in place, disabled, in Rest and while Paused`() {
        #expect(display(.running(phase: rest, endsAt: at(160)), workTime: .seconds(40)).doneButton == .disabled)
        #expect(display(.paused(phase: rest, timeLeft: .seconds(5)), workTime: .seconds(40)).doneButton == .disabled)
        #expect(display(.pausedOpen(phase: work, elapsed: .seconds(5))).doneButton == .disabled)
    }
}
