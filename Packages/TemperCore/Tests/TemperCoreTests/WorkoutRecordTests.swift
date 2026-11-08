import Testing

@testable import TemperCore

/// The Workout record the engine hands over with its ended snapshot. `nonisolated` because the engine runs off the
/// main actor, and every wait is on a snapshot.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct WorkoutRecordTests {
    private typealias Record = WorkoutRecord<ManualClock.Instant>

    private let clock = ManualClock()

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    /// Moves the clock to a time since the test began, as a single wake.
    private func advance(to seconds: Double) {
        clock.advance(by: clock.now.duration(to: at(seconds)))
    }

    private func phase(_ kind: Phase.Kind, round: Int? = nil, from start: Double, to end: Double)
        -> Record.RecordedPhase
    {
        Record.RecordedPhase(kind: kind, round: round, start: at(start), end: at(end))
    }

    private func makeEngine(_ workout: Workout) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
    }

    /// Reads the rest of the snapshots and returns the ended one's record.
    private func record(of snapshots: AsyncStream<WorkoutSnapshot<ManualClock.Instant>>.Iterator) async -> Record? {
        var snapshots = snapshots
        while let snapshot = await snapshots.next(isolation: #isolation) {
            if let record = snapshot.record { return record }
        }
        return nil
    }

    // MARK: Any Workout Type that finishes

    /// The Live Activity's complete state shows the record's active time, and the complete screen shows the
    /// Workout's length, so a finished Workout's two must agree.
    @Test(arguments: [WorkoutType.intervals, .stopwatch])
    func `A finished Workout's active time is its length, with its Pause left out`(type: WorkoutType) async {
        let workout = type.makeWorkout(from: type.firstLaunch)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 5)
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        advance(to: 65)
        await engine.resume(at: clock.now)

        advance(to: 10_000)

        let record = await record(of: snapshots)
        #expect(record?.activeTime == workout.totalDuration)
    }

    // MARK: Intervals

    /// Prepare 0:10, then Work 0:30, Rest 0:15, Work 0:30, and Cooldown 1:00, finishing after 2:25 of active time.
    private let intervals = Workout(phases: [
        Phase(kind: .prepare, duration: .seconds(10)),
        Phase(kind: .work, duration: .seconds(30), round: 1),
        Phase(kind: .rest, duration: .seconds(15), round: 1),
        Phase(kind: .work, duration: .seconds(30), round: 2),
        Phase(kind: .cooldown, duration: .seconds(60)),
    ])

    @Test func `A finished Intervals records every Phase and its Pause, even ones the engine never published`() async {
        let engine = makeEngine(intervals)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 50)
        _ = await snapshots.next()
        await engine.pause(at: clock.now)
        advance(to: 70)
        await engine.resume(at: clock.now)

        // One late wake, long after the finish, skips the last Work and the Cooldown on screen.
        advance(to: 1_000)

        let record = await record(of: snapshots)
        #expect(
            record
                == Record(
                    start: at(0),
                    end: at(165),
                    pauses: [at(50)..<at(70)],
                    phases: [
                        phase(.prepare, from: 0, to: 10),
                        phase(.work, round: 1, from: 10, to: 40),
                        phase(.rest, round: 1, from: 40, to: 75),
                        phase(.work, round: 2, from: 75, to: 105),
                        phase(.cooldown, from: 105, to: 165),
                    ]
                )
        )
        #expect(record?.activeTime == .seconds(145))
        #expect(record?.workTimes == [.seconds(30), .seconds(30)])
    }

    @Test func `A Pause tapped past the finish isn't a Pause, and the record ends at the finish`() async {
        let engine = makeEngine(intervals)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advanceWhileSuspended(by: .seconds(150))

        await engine.pause(at: clock.now)

        let record = await record(of: snapshots)
        #expect(record?.end == at(145))
        #expect(record?.pauses == [])
        #expect(record?.phases.last == phase(.cooldown, from: 85, to: 145))
    }

    @Test func `A Stop that arrives after the finish ends the record at the finish`() async {
        let engine = makeEngine(intervals)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advanceWhileSuspended(by: .seconds(150))

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(record?.end == at(145))
        #expect(record?.activeTime == .seconds(145))
    }

    // MARK: Stopwatch

    @Test func `A Stopped Stopwatch ends its Work at the tap, however late the engine hears of it`() async {
        let engine = makeEngine(WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch))
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 10)
        _ = await snapshots.next()
        advance(to: 100)
        let tap = clock.now
        clock.advanceWhileSuspended(by: .milliseconds(400))

        await engine.stop(at: tap)

        let record = await record(of: snapshots)
        #expect(
            record
                == Record(
                    start: at(0),
                    end: at(100),
                    pauses: [],
                    phases: [phase(.prepare, from: 0, to: 10), phase(.work, from: 10, to: 100)]
                )
        )
        #expect(record?.activeTime == .seconds(100))
        #expect(record?.workTimes == [.seconds(90)])
    }

    @Test func `A Workout Stopped before it started records nothing`() async {
        let engine = makeEngine(intervals)
        let snapshots = engine.snapshots.makeAsyncIterator()
        advance(to: 3)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(record == Record(start: at(3), end: at(3), pauses: [], phases: []))
        #expect(record?.activeTime == .zero)
        #expect(record?.workTimes == [])
    }

    // MARK: Open Rounds

    /// Open Rounds with a Rest of 1:00, Done at 25 s, so Round 1's Rest runs from 25 to 85 s and Round 2's Work
    /// starts at 85 s.
    private func startOpenRounds() async -> (
        WorkoutEngine<ManualClock>, AsyncStream<WorkoutSnapshot<ManualClock.Instant>>.Iterator
    ) {
        let engine = makeEngine(WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch))
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next(isolation: #isolation)
        advance(to: 25)
        await engine.done(at: clock.now)
        _ = await snapshots.next(isolation: #isolation)
        return (engine, snapshots)
    }

    @Test func `Open Rounds Stopped in Work ends that Work at the Stop, and its Work time leaves out its Pause`() async
    {
        var (engine, snapshots) = await startOpenRounds()
        advance(to: 85)
        _ = await snapshots.next()
        advance(to: 100)
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        advance(to: 110)
        await engine.resume(at: clock.now)
        _ = await snapshots.next()
        advance(to: 130)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(
            record
                == Record(
                    start: at(0),
                    end: at(130),
                    pauses: [at(100)..<at(110)],
                    phases: [
                        phase(.work, round: 1, from: 0, to: 25),
                        phase(.rest, round: 1, from: 25, to: 85),
                        phase(.work, round: 2, from: 85, to: 130),
                    ]
                )
        )
        #expect(record?.workTimes == [.seconds(25), .seconds(35)])
        #expect(record?.activeTime == .seconds(120))
    }

    @Test func `Open Rounds Stopped in Rest ends the Rest at the Stop, and the next Work isn't in it`() async {
        let (engine, snapshots) = await startOpenRounds()
        advance(to: 50)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(
            record?.phases == [
                phase(.work, round: 1, from: 0, to: 25),
                phase(.rest, round: 1, from: 25, to: 50),
            ]
        )
        #expect(record?.workTimes == [.seconds(25)])
        #expect(record?.activeTime == .seconds(50))
    }

    @Test func `Open Rounds Stopped as its Rest ends doesn't record the Work that would have started then`() async {
        let (engine, snapshots) = await startOpenRounds()
        advance(to: 85)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(
            record?.phases == [
                phase(.work, round: 1, from: 0, to: 25),
                phase(.rest, round: 1, from: 25, to: 85),
            ]
        )
        #expect(record?.workTimes == [.seconds(25)])
    }

    @Test func `Open Rounds Stopped while Paused ends that Pause and its Phase at the Stop`() async {
        var (engine, snapshots) = await startOpenRounds()
        advance(to: 85)
        _ = await snapshots.next()
        advance(to: 100)
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        advance(to: 130)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(record?.end == at(130))
        #expect(record?.pauses == [at(100)..<at(130)])
        #expect(record?.phases.last == phase(.work, round: 2, from: 85, to: 130))
        #expect(record?.workTimes == [.seconds(25), .seconds(15)])
        #expect(record?.activeTime == .seconds(100))
    }

    @Test func `A Pause tapped as a Phase starts belongs to that Phase`() async {
        var (engine, snapshots) = await startOpenRounds()
        advance(to: 85)
        _ = await snapshots.next()
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        advance(to: 95)
        await engine.resume(at: clock.now)
        _ = await snapshots.next()
        advance(to: 105)

        await engine.stop(at: clock.now)

        let record = await record(of: snapshots)
        #expect(
            record?.phases.suffix(2) == [
                phase(.rest, round: 1, from: 25, to: 85), phase(.work, round: 2, from: 85, to: 105),
            ])
        #expect(record?.workTimes == [.seconds(25), .seconds(10)])
    }
}
