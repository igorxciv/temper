import Testing

@testable import TemperCore

/// The spec's interruptions table, row by row, through the engine's public interface. `nonisolated` because the
/// engine runs off the main actor. Every wait is on an audio call or a snapshot, and the time limit only turns
/// one that never arrives into a failure.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct InterruptionTests {
    private typealias Call = FakeAudioOutput.Call

    /// How each recovery trigger reaches the engine, apart from the one before each Cue.
    enum Trigger: CaseIterable {
        case resumeRecommended
        case returningToTheFront
    }

    private let prepare = Phase(kind: .prepare, duration: .seconds(10))
    private let firstWork = Phase(kind: .work, duration: .seconds(30), round: 1)
    private let rest = Phase(kind: .rest, duration: .seconds(15), round: 1)
    private let secondWork = Phase(kind: .work, duration: .seconds(30), round: 2)
    private let cooldown = Phase(kind: .cooldown, duration: .seconds(60))

    private let clock = ManualClock()
    private let audio = FakeAudioOutput()

    /// Cues are due at 10, 40, 55, 85 and 145 s.
    private func makeEngine(isDipOn: Bool = false) -> WorkoutEngine<ManualClock> {
        makeEngine([prepare, firstWork, rest, secondWork, cooldown], isDipOn: isDipOn)
    }

    private func makeEngine(_ phases: [Phase], isDipOn: Bool = false) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: Workout(phases: phases), clock: clock, audio: audio, isDipOn: isDipOn)
    }

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
    }

    private func running(_ phase: Phase, endsAt end: Double) -> WorkoutSnapshot<ManualClock.Instant>.Progress {
        .running(phase: phase, endsAt: at(end))
    }

    /// Lets calls, returns and events already on their way land, with no real sleep. Correct code passes
    /// however little this waits. It's what gets a wrong call made in time for a test to catch it.
    private func letAudioSettle() async {
        for _ in 0..<100 {
            _ = await audio.history
            await Task.yield()
        }
    }

    /// Moves the clock to a time since the test began, as a single wake.
    private func advance(to seconds: Double) {
        clock.advance(by: clock.now.duration(to: at(seconds)))
    }

    private func recover(_ engine: WorkoutEngine<ManualClock>, by trigger: Trigger) async {
        switch trigger {
        case .resumeRecommended: audio.send(.resumeRecommended)
        case .returningToTheFront: await engine.refresh()
        }
    }

    /// Starts an engine with audio ready, and returns the calls that follow its first activate.
    private func start(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        return calls
    }

    /// Starts an engine and hands over the first Cue, "Work" due at 10 s.
    private func startToFirstCue(
        _ engine: WorkoutEngine<ManualClock>,
        isDipOn: Bool = false
    ) async -> AsyncStream<Call>.Iterator {
        var calls = await start(engine)
        advance(to: 8.5)
        if isDipOn {
            #expect(await calls.next() == .activate(ducking: true))
        }
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        return calls
    }

    // MARK: Accepted call

    @Test(arguments: [AudioEvent.interrupted, .mediaServicesReset, .routeChanged])
    func `An interruption never pauses the Workout, and Phases still change at their exact ends`(
        event: AudioEvent
    ) async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        _ = await start(engine)
        _ = await snapshots.next()
        advance(to: 4)

        audio.send(event)
        await letAudioSettle()

        advance(to: 10)
        #expect(await snapshots.next()?.progress == running(firstWork, endsAt: 40))
        advance(to: 40)
        #expect(await snapshots.next()?.progress == running(rest, endsAt: 55))
    }

    @Test func `No Cue plays during a phone call, and Dip stays off`() async {
        let engine = makeEngine(isDipOn: true)
        _ = await start(engine)
        await audio.setCall(true)
        audio.send(.interrupted)
        await letAudioSettle()

        advance(to: 8.5)
        await letAudioSettle()
        advance(to: 10)
        await letAudioSettle()

        #expect(await audio.history == [.activate(ducking: false)])
    }

    @Test(arguments: Trigger.allCases)
    func `Recovery does nothing during a phone call`(trigger: Trigger) async {
        let engine = makeEngine()
        _ = await start(engine)
        await audio.setCall(true)
        audio.send(.interrupted)
        await letAudioSettle()

        await recover(engine, by: trigger)
        await letAudioSettle()

        #expect(await audio.history == [.activate(ducking: false)])
    }

    @Test func `A Cue held back by a call plays if the call ends and recovery comes up to 1s after its deadline`()
        async
    {
        let engine = makeEngine()
        var calls = await start(engine)
        await audio.setCall(true)
        audio.send(.interrupted)
        await letAudioSettle()
        advance(to: 8.5)
        await letAudioSettle()

        await audio.setCall(false)
        advance(to: 11)
        audio.send(.resumeRecommended)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A Cue held back by a call is skipped if recovery comes more than 1s after its deadline`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        await audio.setCall(true)
        advance(to: 8.5)
        await letAudioSettle()

        await audio.setCall(false)
        advance(to: 11.25)
        await engine.refresh()

        // iOS never interrupted the session, so the Cue's own session is all that went, and recovery brings it.
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `After a call, the next Cue plays without Temper being opened, if iOS lets it run`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        await audio.setCall(true)
        audio.send(.interrupted)
        await letAudioSettle()
        advance(to: 20)
        await letAudioSettle()

        await audio.setCall(false)
        advance(to: 38.5)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `After a call with no word from iOS, opening Temper brings audio back`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        await audio.setCall(true)
        audio.send(.interrupted)
        await letAudioSettle()
        advance(to: 20)
        await audio.setCall(false)

        await engine.refresh()

        #expect(await calls.next() == .activate(ducking: false))
    }

    // MARK: Workout finishes during the silence

    @Test func `A Workout that finished during the silence opens on the complete screen, with no late Cue`() async {
        let engine = makeEngine([firstWork])
        var snapshots = engine.snapshots.makeAsyncIterator()
        var calls = await start(engine)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        _ = await snapshots.next()
        audio.send(.interrupted)
        await letAudioSettle()
        clock.advanceWhileSuspended(by: .seconds(100))

        await engine.refresh()

        #expect(await snapshots.next()?.progress == .finished)
        #expect(await calls.next() == .deactivate)
        await letAudioSettle()
        #expect(await audio.history.contains(.schedule(.workoutComplete, at: at(30))) == false)
    }

    // MARK: Cue interrupted before its deadline

    @Test(arguments: [AudioEvent.interrupted, .mediaServicesReset], Trigger.allCases)
    func `A Cue interrupted before its deadline is cut, and scheduled again on recovery up to 1s after it`(
        event: AudioEvent,
        trigger: Trigger
    ) async {
        let engine = makeEngine()
        var calls = await startToFirstCue(engine)
        advance(to: 9)
        audio.send(event)
        #expect(await calls.next() == .cancel)

        advance(to: 11)
        await recover(engine, by: trigger)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A Cue scheduled again on recovery gets its Dip`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startToFirstCue(engine, isDipOn: true)
        advance(to: 9)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        audio.send(.resumeRecommended)

        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test(arguments: Trigger.allCases)
    func `A Cue interrupted before its deadline is skipped on recovery more than 1s after it, with no Dip`(
        trigger: Trigger
    ) async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startToFirstCue(engine, isDipOn: true)
        advance(to: 9)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        advance(to: 11.25)
        await recover(engine, by: trigger)

        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 38.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A Cue interrupted before its deadline with no recovery is skipped, and the next Cue recovers`() async {
        let engine = makeEngine()
        var calls = await startToFirstCue(engine)
        advance(to: 9)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        advance(to: 38.5)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A schedule that returns after an interruption does nothing to the Cue`() async {
        await audio.onNext(.schedule(.work, at: at(10)), .hold)
        let engine = makeEngine()
        var calls = await startToFirstCue(engine)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        await audio.release(failing: true)
        await letAudioSettle()
        audio.send(.resumeRecommended)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    // MARK: Cue interrupted after it started speaking

    @Test(arguments: [false, true])
    func `A Cue interrupted after it started speaking is cut and never restarted`(isDipOn: Bool) async {
        let engine = makeEngine(isDipOn: isDipOn)
        var calls = await startToFirstCue(engine, isDipOn: isDipOn)
        advance(to: 10.25)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        audio.send(.resumeRecommended)

        // Recovery restarts audio undipped, with no Cue, so the next call is the next Cue's own.
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 38.5)
        if isDipOn {
            #expect(await calls.next() == .activate(ducking: true))
        }
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A finish reported for a Cue cut by an interruption lifts nothing`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startToFirstCue(engine, isDipOn: true)
        advance(to: 10.25)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        await audio.finishSpeaking()
        await letAudioSettle()
        await engine.pause(at: clock.now)

        // The session is already gone, so a lift would be the only thing ahead of the release.
        #expect(await calls.next() == .deactivate)
    }

    @Test func `An interruption while "Workout complete" speaks releases the session`() async {
        let engine = makeEngine([firstWork])
        var snapshots = engine.snapshots.makeAsyncIterator()
        var calls = await start(engine)
        _ = await calls.next()
        await audio.finishSpeaking()
        advance(to: 28.5)
        #expect(await calls.next() == .schedule(.workoutComplete, at: at(30)))
        _ = await snapshots.next()
        advance(to: 30.5)
        #expect(await snapshots.next()?.progress == .finished)

        audio.send(.interrupted)

        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
    }

    // MARK: Audio route changes

    @Test func `A route change between Cues restarts audio at once, and the next Cue uses it`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        advance(to: 4)

        audio.send(.routeChanged)

        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test(arguments: [false, true])
    func `A route change before a Cue's deadline restarts audio and schedules the Cue again`(isDipOn: Bool) async {
        let engine = makeEngine(isDipOn: isDipOn)
        var calls = await startToFirstCue(engine, isDipOn: isDipOn)
        advance(to: 9)

        audio.send(.routeChanged)

        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .activate(ducking: isDipOn))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A route change while a Cue speaks restarts audio without repeating the Cue`() async {
        let engine = makeEngine()
        var calls = await startToFirstCue(engine)
        advance(to: 10.5)

        audio.send(.routeChanged)

        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A route change during an interruption waits for recovery`() async {
        let engine = makeEngine()
        _ = await start(engine)
        advance(to: 4)
        audio.send(.interrupted)

        audio.send(.routeChanged)
        await letAudioSettle()

        #expect(await audio.history == [.activate(ducking: false)])
    }

    @Test func `A route change during a Pause touches no audio, and Resume restarts it`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        audio.send(.routeChanged)
        await letAudioSettle()
        #expect(await audio.history == [.activate(ducking: false), .deactivate])

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: false))
    }

    // MARK: iOS resets its media services

    @Test func `After a media-services reset, audio waits for the next recovery trigger`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        advance(to: 4)

        audio.send(.mediaServicesReset)
        await letAudioSettle()
        #expect(await audio.history == [.activate(ducking: false)])

        await engine.refresh()
        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `After a media-services reset, the next Cue rebuilds audio and plays`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        advance(to: 4)
        audio.send(.mediaServicesReset)
        await letAudioSettle()

        advance(to: 8.5)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    // MARK: Recovery

    @Test(arguments: Trigger.allCases)
    func `A failed recovery shows nothing and doesn't loop, and the next trigger tries again`(trigger: Trigger) async {
        let engine = makeEngine()
        var snapshots = engine.snapshots.makeAsyncIterator()
        var calls = await start(engine)
        _ = await snapshots.next()
        advance(to: 4)
        audio.send(.interrupted)
        await letAudioSettle()
        await audio.onNext(.activate(ducking: false), .fail)

        audio.send(.resumeRecommended)
        #expect(await calls.next() == .activate(ducking: false))
        await letAudioSettle()
        #expect(await audio.history == [.activate(ducking: false), .activate(ducking: false)])

        await recover(engine, by: trigger)
        #expect(await calls.next() == .activate(ducking: false))
        if trigger == .returningToTheFront {
            _ = await snapshots.next()
        }
        advance(to: 10)
        #expect(await snapshots.next()?.progress == running(firstWork, endsAt: 40))
    }

    @Test func `Recovery triggers that arrive together restart audio once`() async {
        let engine = makeEngine()
        _ = await start(engine)
        advance(to: 4)
        audio.send(.interrupted)
        await letAudioSettle()

        audio.send(.resumeRecommended)
        await engine.refresh()
        await letAudioSettle()

        #expect(await audio.history == [.activate(ducking: false), .activate(ducking: false)])
    }

    @Test(arguments: Trigger.allCases)
    func `Recovery with audio still in place does nothing`(trigger: Trigger) async {
        let engine = makeEngine()
        _ = await start(engine)
        advance(to: 4)

        await recover(engine, by: trigger)
        await letAudioSettle()

        #expect(await audio.history == [.activate(ducking: false)])
    }

    @Test func `Opening Temper brings back audio that failed at Start, ahead of the next Cue`() async {
        await audio.onNext(.activate(ducking: false), .fail)
        let engine = makeEngine()
        var calls = await start(engine)
        advance(to: 4)

        await engine.refresh()

        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test(arguments: [AudioEvent.interrupted, .mediaServicesReset])
    func `An interruption during a Pause changes nothing, and Resume restarts audio`(event: AudioEvent) async {
        let engine = makeEngine()
        var calls = await start(engine)
        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        audio.send(event)
        audio.send(.resumeRecommended)
        await engine.refresh()
        await letAudioSettle()
        #expect(await audio.history == [.activate(ducking: false), .deactivate])

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `Stop during an interruption still releases the session`() async {
        let engine = makeEngine()
        var calls = await start(engine)
        audio.send(.interrupted)
        await letAudioSettle()

        await engine.stop()

        #expect(await calls.next() == .deactivate)
    }
}
