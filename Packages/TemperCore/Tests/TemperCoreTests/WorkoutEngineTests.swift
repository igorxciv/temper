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

        #expect(await snapshots.next() == Snapshot(progress: .finished, rounds: 1))
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

        #expect(await snapshots.next() == Snapshot(progress: .finished, rounds: 2))
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
        await engine.stop()

        #expect(await snapshots.next() == Snapshot(progress: .stopped, rounds: 2))
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

        #expect(await snapshots.next() == Snapshot(progress: .finished, rounds: 2))
        #expect(await snapshots.next() == nil)
    }

    // MARK: Stop

    @Test(arguments: [Duration.seconds(4), .seconds(20), .seconds(45), .seconds(70), .seconds(100)])
    func `Stop ends the Workout in every Phase`(active: Duration) async {
        var (engine, snapshots) = await engine(runFor: active)

        await engine.stop()

        #expect(await snapshots.next() == Snapshot(progress: .stopped, rounds: 2))
        #expect(await snapshots.next() == nil)
    }

    @Test func `Stop during a Pause ends the Workout`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()

        await engine.stop()

        #expect(await snapshots.next() == Snapshot(progress: .stopped, rounds: 2))
        #expect(await snapshots.next() == nil)
    }

    @Test func `No Phase changes after Stop, and later calls do nothing`() async {
        var (engine, snapshots) = await engine(runFor: .seconds(4))
        await engine.stop()
        _ = await snapshots.next()

        clock.advance(by: .seconds(1_000))
        await engine.start()
        await engine.pause(at: clock.now)
        await engine.resume(at: clock.now)
        await engine.refresh()
        await engine.stop()

        #expect(await snapshots.next() == nil)
    }

    @Test func `Pause and Stop after the finish do nothing`() async {
        let engine = makeEngine([firstWork])
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(30))
        #expect(await snapshots.next() == Snapshot(progress: .finished, rounds: 1))

        await engine.pause(at: clock.now)
        await engine.stop()

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

        #expect(await snapshots.next() == Snapshot(progress: .finished, rounds: 2))
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
}
