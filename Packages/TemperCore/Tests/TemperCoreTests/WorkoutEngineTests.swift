import Testing

@testable import TemperCore

/// `nonisolated` because the engine runs off the main actor. Every wait is on a snapshot, and the time
/// limit only turns a snapshot that never arrives into a failure.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct WorkoutEngineTests {
    private typealias Snapshot = WorkoutSnapshot<ManualClock.Instant>

    private let prepare = Phase(kind: .prepare, duration: .seconds(10))
    private let firstWork = Phase(kind: .work, duration: .seconds(30), round: 1)
    private let rest = Phase(kind: .rest, duration: .seconds(15), round: 1)
    private let secondWork = Phase(kind: .work, duration: .seconds(30), round: 2)
    private let cooldown = Phase(kind: .cooldown, duration: .seconds(60))

    private let clock = ManualClock()

    private func makeEngine(_ phases: [Phase]) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: Workout(phases: phases), clock: clock, audio: FakeAudioOutput(), isDipOn: false)
    }

    /// Phases start at 0, 10, 40, 55 and 85 s, and the Workout finishes at 145 s.
    private func makeEngine() -> WorkoutEngine<ManualClock> {
        makeEngine([prepare, firstWork, rest, secondWork, cooldown])
    }

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func running(_ phase: Phase, endsAt end: Double) -> Snapshot {
        Snapshot(progress: .running(phase: phase, endsAt: at(end)), rounds: 2)
    }

    @Test func `Start publishes the first Phase, ending its full length after the start point`() async {
        let engine = makeEngine()
        clock.advance(by: .seconds(7))
        var snapshots = engine.snapshots.makeAsyncIterator()

        await engine.start()

        #expect(await snapshots.next() == running(prepare, endsAt: 17))
    }

    @Test func `Starting twice changes nothing`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advanceWhileSuspended(by: .seconds(3))

        await engine.start()
        await engine.pause(at: clock.now)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(7)), rounds: 2))
    }

    @Test func `Phases change on their own at their exact ends`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(10))
        #expect(await snapshots.next() == running(firstWork, endsAt: 40))

        clock.advance(by: .seconds(30))
        #expect(await snapshots.next() == running(rest, endsAt: 55))

        clock.advance(by: .seconds(15))
        #expect(await snapshots.next() == running(secondWork, endsAt: 85))

        clock.advance(by: .seconds(30))
        #expect(await snapshots.next() == running(cooldown, endsAt: 145))
    }

    @Test func `The Workout finishes at its total length and the snapshots end`() async {
        let engine = makeEngine([firstWork])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(30))

        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await snapshots.next() == nil)
    }

    @Test func `Every sleep uses the 10 ms tolerance`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(10))
        _ = await snapshots.next()
        clock.advance(by: .seconds(30))
        _ = await snapshots.next()

        #expect(!clock.tolerances.isEmpty)
        #expect(clock.tolerances.allSatisfy { $0 == .milliseconds(10) })
    }

    @Test func `Nothing is published between events`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .milliseconds(9_999))
        await engine.pause(at: clock.now)

        // Had the engine published anything for the wait, it would arrive ahead of the Pause.
        #expect(
            await snapshots.next()
                == Snapshot(progress: .paused(phase: prepare, timeLeft: .milliseconds(1)), rounds: 2)
        )
    }

    @Test func `A wake ahead of the Phase's end publishes nothing and sleeps again`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        var sleeps = clock.sleepsStarted.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        _ = await sleeps.next()

        clock.advance(by: .seconds(4))
        clock.wakeSleepersEarly()
        _ = await sleeps.next()
        await engine.pause(at: clock.now)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(6)), rounds: 2))
    }

    @Test func `A late wake keeps later Phase ends on the fixed start point`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .milliseconds(10_500))

        #expect(await snapshots.next() == running(firstWork, endsAt: 40))
    }

    @Test func `A late wake passes missed Phases silently`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(60))

        #expect(await snapshots.next() == running(secondWork, endsAt: 85))
    }

    @Test func `A wake past the finish goes straight to finished`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(1_000))

        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await snapshots.next() == nil)
    }

    // MARK: Pause and Resume

    /// An engine moved to `active` seconds, with its snapshots read up to that point.
    private func engine(
        runFor active: Duration
    ) async -> (WorkoutEngine<ManualClock>, AsyncStream<Snapshot>.Iterator) {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: active)
        if active >= .seconds(10) {
            _ = await snapshots.next()
        }
        return (engine, snapshots)
    }

    @Test(arguments: [
        (Duration.seconds(4), Phase.Kind.prepare, 6.0),
        (.seconds(20), .work, 20),
        (.seconds(45), .rest, 10),
        (.seconds(100), .cooldown, 45),
    ])
    func `Pause and Resume keep the exact time left in every Phase`(
        active: Duration,
        kind: Phase.Kind,
        timeLeft: Double
    ) async throws {
        var (engine, snapshots) = await engine(runFor: active)
        let phase = try #require([prepare, firstWork, rest, cooldown].first { $0.kind == kind })

        await engine.pause(at: clock.now)
        #expect(
            await snapshots.next()
                == Snapshot(progress: .paused(phase: phase, timeLeft: .seconds(timeLeft)), rounds: 2)
        )

        clock.advance(by: .seconds(500))
        await engine.resume(at: clock.now)

        let resumedAt = active + .seconds(500)
        #expect(
            await snapshots.next()
                == Snapshot(
                    progress: .running(phase: phase, endsAt: at(0).advanced(by: resumedAt + .seconds(timeLeft))),
                    rounds: 2
                )
        )
    }

    /// A first-launch Stopwatch is a Prepare of 0:10 and a Work of 10:00.
    @Test(arguments: [(4.0, Phase.Kind.prepare, 6.0), (100, .work, 510)])
    func `Pause and Resume keep the exact time left in every Stopwatch Phase`(
        active: Double,
        kind: Phase.Kind,
        timeLeft: Double
    ) async throws {
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        let phase = try #require(workout.phases.first { $0.kind == kind })
        let engine = WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(active))
        if kind == .work {
            _ = await snapshots.next()
        }

        await engine.pause(at: clock.now)
        #expect(
            await snapshots.next() == Snapshot(progress: .paused(phase: phase, timeLeft: .seconds(timeLeft)), rounds: 0)
        )

        clock.advance(by: .seconds(500))
        await engine.resume(at: clock.now)
        #expect(
            await snapshots.next()
                == Snapshot(progress: .running(phase: phase, endsAt: at(active + 500 + timeLeft)), rounds: 0)
        )
    }

    @Test func `A Pause uses the time of the tap, however late the engine hears of it`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        let tap = clock.now
        clock.advanceWhileSuspended(by: .milliseconds(300))

        await engine.pause(at: tap)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(6)), rounds: 2))
    }

    @Test func `A Resume uses the time of the tap, however late the engine hears of it`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .seconds(10))
        let tap = clock.now
        clock.advanceWhileSuspended(by: .milliseconds(300))

        await engine.resume(at: tap)

        #expect(await snapshots.next() == running(prepare, endsAt: 20))
    }

    @Test func `A Pause tapped just before a Phase's end holds that Phase, even if the engine moved on first`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(9))
        let tap = clock.now
        clock.advance(by: .seconds(1))
        _ = await snapshots.next()

        await engine.pause(at: tap)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(1)), rounds: 2))
    }

    @Test func `A paused Workout never changes Phase on its own`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(9))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(1_000))
        await engine.stop(at: clock.now)

        #expect(await snapshots.next()?.wasStopped == true)
    }

    @Test func `Phases carry on from a Resume with the Pause left out`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .seconds(100))
        await engine.resume(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(6))

        #expect(await snapshots.next() == running(firstWork, endsAt: 140))
    }

    @Test func `Pausing twice and resuming twice change nothing`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.resume(at: clock.now)
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .seconds(1))
        await engine.pause(at: clock.now)
        await engine.resume(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .seconds(1))

        await engine.resume(at: clock.now)
        await engine.pause(at: clock.now)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(5)), rounds: 2))
    }

    @Test func `A Pause tapped past the finish finishes the Workout, because there is no Phase to hold`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        clock.advanceWhileSuspended(by: .seconds(1_000))

        await engine.pause(at: clock.now)

        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await snapshots.next() == nil)
    }

    // MARK: Stop

    @Test(arguments: [Duration.seconds(4), .seconds(20), .seconds(45), .seconds(70), .seconds(100)])
    func `Stop ends the Workout in every Phase`(active: Duration) async {
        var (engine, snapshots) = await engine(runFor: active)

        await engine.stop(at: clock.now)

        #expect(await snapshots.next()?.wasStopped == true)
        #expect(await snapshots.next() == nil)
    }

    @Test func `Stop during a Pause ends the Workout`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()

        await engine.stop(at: clock.now)

        #expect(await snapshots.next()?.wasStopped == true)
        #expect(await snapshots.next() == nil)
    }

    @Test func `No Phase changes after Stop, and later calls do nothing`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.stop(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(1_000))
        await engine.start()
        await engine.pause(at: clock.now)
        await engine.resume(at: clock.now)
        await engine.refresh()
        await engine.stop(at: clock.now)

        #expect(await snapshots.next() == nil)
    }

    @Test func `Pause and Stop after the finish do nothing`() async {
        let engine = makeEngine([firstWork])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(30))
        #expect(await snapshots.next()?.hasFinished == true)

        await engine.pause(at: clock.now)
        await engine.stop(at: clock.now)

        #expect(await snapshots.next() == nil)
    }

    // MARK: Returning to the front

    @Test func `Returning to the front shows the correct Phase after a suspension`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        clock.advanceWhileSuspended(by: .seconds(40))

        await engine.refresh()

        #expect(await snapshots.next() == running(rest, endsAt: 55))
    }

    @Test func `Returning to the front always publishes, even with nothing changed`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))

        await engine.refresh()

        #expect(await snapshots.next() == running(prepare, endsAt: 10))
    }

    @Test func `Returning to the front during a Pause republishes the time left`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        clock.advanceWhileSuspended(by: .seconds(40))

        await engine.refresh()

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: prepare, timeLeft: .seconds(6)), rounds: 2))
    }

    @Test func `Returning to the front after the Workout finished in the background shows it finished`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        clock.advanceWhileSuspended(by: .seconds(1_000))

        await engine.refresh()

        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await snapshots.next() == nil)
    }

    @Test func `Phases keep changing after returning to the front`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        clock.advanceWhileSuspended(by: .seconds(40))
        await engine.refresh()
        _ = await snapshots.next()

        clock.advance(by: .seconds(11))

        #expect(await snapshots.next() == running(secondWork, endsAt: 85))
    }

    // MARK: Open Phases

    private let openWork = Phase(kind: .work, length: .open, round: 1)

    private func runningOpen(since start: Double) -> Snapshot {
        Snapshot(progress: .runningOpen(phase: openWork, startedAt: at(start)), rounds: nil)
    }

    private func pausedOpen(elapsed: Double) -> Snapshot {
        Snapshot(progress: .pausedOpen(phase: openWork, elapsed: .seconds(elapsed)), rounds: nil)
    }

    /// Moves the clock to a time since the test began, as a single wake.
    private func advance(to seconds: Double) {
        clock.advance(by: clock.now.duration(to: at(seconds)))
    }

    @Test func `An open Phase is published with its start, and no set number of Rounds`() async {
        let engine = makeEngine([prepare, openWork, rest])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(10))

        #expect(await snapshots.next() == runningOpen(since: 10))
    }

    @Test func `An open Phase publishes nothing however long it runs, and Pause holds its time spent`() async {
        let engine = makeEngine([openWork, rest])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        #expect(await snapshots.next() == runningOpen(since: 0))

        clock.advance(by: .seconds(10_000))
        let tap = clock.now
        clock.advanceWhileSuspended(by: .milliseconds(300))
        await engine.pause(at: tap)

        // Had the engine published anything for the wait, it would arrive ahead of the Pause.
        #expect(
            await snapshots.next()
                == Snapshot(progress: .pausedOpen(phase: openWork, elapsed: .seconds(10_000)), rounds: nil)
        )
    }

    @Test func `Resume moves an open Phase's start later by exactly the Pause`() async {
        let engine = makeEngine([openWork, rest])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(25))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(40))
        await engine.resume(at: clock.now)

        #expect(await snapshots.next() == runningOpen(since: 40))
    }

    // MARK: Done

    private let doneRest = Phase(kind: .rest, duration: .seconds(30), round: 1)
    private let lastWork = Phase(kind: .work, duration: .seconds(30), round: 2)

    /// An open Work, then a Rest of 0:30, then a Work of 0:30.
    private func makeDoneEngine() -> WorkoutEngine<ManualClock> {
        makeEngine([openWork, doneRest, lastWork])
    }

    /// A Phase after Done, carrying the time of the open Work just before it, if there was one.
    private func runningAfterDone(_ phase: Phase, endsAt end: Double, workTime: Double? = nil) -> Snapshot {
        Snapshot(
            progress: .running(phase: phase, endsAt: at(end)),
            rounds: nil,
            previousOpenPhaseTime: workTime.map { .seconds($0) }
        )
    }

    @Test func `An open Work publishes nothing until Done, however far the clock advances`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        #expect(await snapshots.next() == runningOpen(since: 0))

        clock.advance(by: .seconds(10_000))
        await engine.done(at: clock.now)

        // Had the engine published anything for the wait, it would arrive ahead of the Rest.
        #expect(await snapshots.next() == runningAfterDone(doneRest, endsAt: 10_030, workTime: 10_000))
    }

    @Test func `Done ends the open Work at the tap, however late the engine hears of it`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        let tap = clock.now

        clock.advanceWhileSuspended(by: .milliseconds(400))
        await engine.done(at: tap)

        #expect(await snapshots.next() == runningAfterDone(doneRest, endsAt: 70, workTime: 40))
    }

    @Test func `The Phase after the Rest starts at the Rest's exact end, and the Workout finishes after it`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(30))
        #expect(await snapshots.next() == runningAfterDone(lastWork, endsAt: 100))

        clock.advance(by: .seconds(30))
        #expect(await snapshots.next()?.hasFinished == true)
    }

    @Test func `A second Done that lands in the Rest does nothing`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .milliseconds(200))
        await engine.done(at: clock.now)
        clock.advance(by: .seconds(5))
        await engine.pause(at: clock.now)

        #expect(
            await snapshots.next()
                == Snapshot(
                    progress: .paused(phase: doneRest, timeLeft: .milliseconds(24_800)),
                    rounds: nil,
                    previousOpenPhaseTime: .seconds(40)
                )
        )
    }

    @Test func `Done does nothing during a Phase with a set length`() async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(10))
        _ = await snapshots.next()

        clock.advance(by: .seconds(5))
        await engine.done(at: clock.now)
        await engine.pause(at: clock.now)

        #expect(
            await snapshots.next() == Snapshot(progress: .paused(phase: firstWork, timeLeft: .seconds(25)), rounds: 2)
        )
    }

    @Test func `Done does nothing in a Stopwatch's Work`() async throws {
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        let work = try #require(workout.phases.first { $0.kind == .work })
        let engine = WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 10)
        _ = await snapshots.next()

        advance(to: 30)
        await engine.done(at: clock.now)
        await engine.pause(at: clock.now)

        #expect(await snapshots.next() == Snapshot(progress: .paused(phase: work, timeLeft: .seconds(580)), rounds: 0))
    }

    @Test func `A Done tapped before an open Phase began does nothing, even if it arrives once it has`() async {
        let engine = makeEngine([prepare, openWork, doneRest])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .milliseconds(9_800))
        let tap = clock.now
        clock.advance(by: .milliseconds(400))
        #expect(await snapshots.next() == runningOpen(since: 10))

        await engine.done(at: tap)
        await engine.pause(at: clock.now)

        #expect(
            await snapshots.next()
                == Snapshot(progress: .pausedOpen(phase: openWork, elapsed: .milliseconds(200)), rounds: nil)
        )
    }

    @Test func `A Done while Paused does nothing, and a Done after Resume ends the open Work at its tap`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(20))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(30))
        await engine.done(at: clock.now)
        clock.advance(by: .seconds(10))
        await engine.resume(at: clock.now)

        // Had the Done while Paused ended the Work, Resume would publish the Rest.
        #expect(await snapshots.next() == runningOpen(since: 40))

        clock.advance(by: .seconds(5))
        await engine.done(at: clock.now)

        #expect(await snapshots.next() == runningAfterDone(doneRest, endsAt: 95, workTime: 25))
    }

    @Test func `Several Pauses in one open Work add up exactly, using the time of each tap`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        /// Moves the clock to `seconds` for the tap, then lets the engine hear of it 300 ms later.
        func tapLate(at seconds: Double, _ send: (ManualClock.Instant) async -> Void) async {
            advance(to: seconds)
            let tap = clock.now
            clock.advanceWhileSuspended(by: .milliseconds(300))
            await send(tap)
        }

        await tapLate(at: 10) { await engine.pause(at: $0) }
        #expect(await snapshots.next() == pausedOpen(elapsed: 10))
        await tapLate(at: 100) { await engine.resume(at: $0) }
        #expect(await snapshots.next() == runningOpen(since: 90))

        await tapLate(at: 115) { await engine.pause(at: $0) }
        #expect(await snapshots.next() == pausedOpen(elapsed: 25))
        await tapLate(at: 122) { await engine.resume(at: $0) }
        #expect(await snapshots.next() == runningOpen(since: 97))

        await tapLate(at: 130) { await engine.pause(at: $0) }
        #expect(await snapshots.next() == pausedOpen(elapsed: 33))
        await tapLate(at: 200) { await engine.resume(at: $0) }
        #expect(await snapshots.next() == runningOpen(since: 167))

        await tapLate(at: 210) { await engine.done(at: $0) }
        #expect(await snapshots.next() == runningAfterDone(doneRest, endsAt: 240, workTime: 43))
    }

    @Test func `Pause and Resume in the Rest after Done keep its exact time left`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        clock.advance(by: .seconds(10))
        await engine.pause(at: clock.now)
        #expect(
            await snapshots.next()
                == Snapshot(
                    progress: .paused(phase: doneRest, timeLeft: .seconds(20)),
                    rounds: nil,
                    previousOpenPhaseTime: .seconds(40)
                )
        )

        clock.advance(by: .seconds(100))
        await engine.resume(at: clock.now)
        #expect(await snapshots.next() == runningAfterDone(doneRest, endsAt: 170, workTime: 40))

        clock.advance(by: .seconds(20))
        #expect(await snapshots.next() == runningAfterDone(lastWork, endsAt: 200))
    }

    @Test func `Done after Stop does nothing`() async {
        let engine = makeDoneEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        await engine.stop(at: clock.now)

        await engine.done(at: clock.now)

        #expect(await snapshots.next()?.wasStopped == true)
        #expect(await snapshots.next() == nil)
    }
}

// MARK: Open Rounds

/// Open Rounds, run end to end: an open Work, a Rest, and the next Round's Work by itself, until Stop.
extension WorkoutEngineTests {
    /// Open Rounds with a Rest of `rest` seconds.
    private func makeOpenRoundsEngine(rest: Int = 60) -> WorkoutEngine<ManualClock> {
        var settings = WorkoutType.openRounds.firstLaunch
        settings[.rest] = rest
        let workout = WorkoutType.openRounds.makeWorkout(from: settings)
        return WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
    }

    /// An open Work, carrying the time of the open Work just before it when a Rest of zero left none between them.
    private func openRoundsWork(round: Int, since start: ManualClock.Instant, workTime: Duration? = nil) -> Snapshot {
        let phase = Phase(kind: .work, length: .open, round: round)
        return Snapshot(
            progress: .runningOpen(phase: phase, startedAt: start), rounds: nil, previousOpenPhaseTime: workTime)
    }

    /// A Rest, carrying the time of the Work it follows.
    private func openRoundsRest(round: Int, endsAt end: ManualClock.Instant, workTime: Duration) -> Snapshot {
        let phase = Phase(kind: .rest, duration: .seconds(60), round: round)
        return Snapshot(progress: .running(phase: phase, endsAt: end), rounds: nil, previousOpenPhaseTime: workTime)
    }

    @Test func `Open Rounds starts straight into Round 1's open Work, with no set number of Rounds`() async {
        let engine = makeOpenRoundsEngine()
        clock.advance(by: .seconds(7))
        var snapshots = engine.snapshots.makeAsyncIterator()

        await engine.start()

        #expect(await snapshots.next() == openRoundsWork(round: 1, since: clock.now))
    }

    @Test func `Each Rest ends into the next Round's open Work, and the Rounds keep counting`() async {
        let engine = makeOpenRoundsEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        for round in 1...20 {
            clock.advance(by: .seconds(25))
            await engine.done(at: clock.now)
            let restEnd = clock.now.advanced(by: .seconds(60))
            #expect(await snapshots.next() == openRoundsRest(round: round, endsAt: restEnd, workTime: .seconds(25)))

            clock.advance(by: .seconds(60))
            #expect(await snapshots.next() == openRoundsWork(round: round + 1, since: clock.now))
        }
    }

    /// The next Round's Work is the open Phase waiting for Done, so a Done in the Rest before it mustn't end it.
    @Test func `A Done well into the Rest does nothing, and the next Work still runs open`() async {
        let engine = makeOpenRoundsEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 25)
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        advance(to: 50)
        await engine.done(at: clock.now)
        advance(to: 85)
        #expect(await snapshots.next() == openRoundsWork(round: 2, since: clock.now))

        advance(to: 95)
        await engine.pause(at: clock.now)
        let work = Phase(kind: .work, length: .open, round: 2)
        #expect(
            await snapshots.next() == Snapshot(progress: .pausedOpen(phase: work, elapsed: .seconds(10)), rounds: nil))
    }

    @Test func `With a Rest of zero, Done goes straight to the next Round's open Work`() async {
        let engine = makeOpenRoundsEngine(rest: 0)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()

        clock.advance(by: .seconds(40))
        await engine.done(at: clock.now)

        #expect(await snapshots.next() == openRoundsWork(round: 2, since: clock.now, workTime: .seconds(40)))
    }

    @Test func `With a Rest of zero, a second Done within 1s of the first does nothing`() async {
        let engine = makeOpenRoundsEngine(rest: 0)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 40)
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        advance(to: 40.2)
        await engine.done(at: clock.now)
        advance(to: 45)
        await engine.pause(at: clock.now)

        let work = Phase(kind: .work, length: .open, round: 2)
        #expect(
            await snapshots.next()
                == Snapshot(
                    progress: .pausedOpen(phase: work, elapsed: .seconds(5)),
                    rounds: nil,
                    previousOpenPhaseTime: .seconds(40)
                )
        )
    }

    @Test func `With a Rest of zero, a Done 1s after the last one ends the next Round's Work`() async {
        let engine = makeOpenRoundsEngine(rest: 0)
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 40)
        await engine.done(at: clock.now)
        _ = await snapshots.next()

        advance(to: 41)
        await engine.done(at: clock.now)

        #expect(await snapshots.next() == openRoundsWork(round: 3, since: clock.now, workTime: .seconds(1)))
    }

    @Test func `The Rest after Done carries the Work time just ended, leaving out its Pause`() async {
        let engine = makeOpenRoundsEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        advance(to: 20)
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        advance(to: 30)
        await engine.resume(at: clock.now)
        _ = await snapshots.next()

        advance(to: 112)
        await engine.done(at: clock.now)
        let workTime = Duration.seconds(102)
        #expect(await snapshots.next() == openRoundsRest(round: 1, endsAt: at(172), workTime: workTime))

        advance(to: 140)
        await engine.pause(at: clock.now)
        #expect(await snapshots.next()?.previousOpenPhaseTime == workTime)
        await engine.resume(at: clock.now)
        _ = await snapshots.next()

        advance(to: 172)
        #expect(await snapshots.next() == openRoundsWork(round: 2, since: at(172)))
    }

    @Test(arguments: [false, true])
    func `Stop during an open Work or a Rest ends Open Rounds`(duringRest: Bool) async {
        let engine = makeOpenRoundsEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(40))
        if duringRest {
            await engine.done(at: clock.now)
            _ = await snapshots.next()
            clock.advance(by: .seconds(20))
        }

        await engine.stop(at: clock.now)

        #expect(await snapshots.next()?.wasStopped == true)
        #expect(await snapshots.next() == nil)
    }
}
