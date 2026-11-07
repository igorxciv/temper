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
        #expect(!stopwatch(.finished).countsUp)
        #expect(!intervals(running(work, endsAt: 100)).countsUp)
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
        let ring = intervals(.finished).ring(at: at(1))

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
        let display = Display(workoutType: type, workout: workout, snapshot: Snapshot(progress: .finished, rounds: 8))

        #expect(display.line == nil)
    }
}

/// An open Phase isn't reachable in the app yet. These only pin down that the display handles one without a made-up
/// value, so the Open Rounds screens start from a sound place.
nonisolated struct RunningDisplayOpenPhaseTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>
    private typealias Display = RunningDisplay<ManualClock.Instant>

    private let openWork = Phase(kind: .work, length: .open, round: 3)

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func display(_ progress: Snapshot.Progress) -> Display {
        let workout = Workout(phases: [openWork, Phase(kind: .rest, duration: .seconds(60), round: 3)])
        return Display(workoutType: .intervals, workout: workout, snapshot: Snapshot(progress: progress, rounds: nil))
    }

    @Test func `An open Phase counts up from its start, rounding down`() {
        let display = display(.runningOpen(phase: openWork, startedAt: at(100)))

        let ring = display.ring(at: at(164.9))

        #expect(display.countsUp)
        #expect(ring.time == "01:04")
        #expect(ring.spokenTime == "1 minute 4 seconds elapsed")
    }

    @Test func `With no set number of Rounds, the line shows the Round with no total`() {
        #expect(
            display(.runningOpen(phase: openWork, startedAt: at(0))).line
                == .value("3", caption: .before("Round"), spoken: "Round 3")
        )
    }
}
