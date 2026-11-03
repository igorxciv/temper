import Testing

@testable import TemperCore

/// `nonisolated` because the engine runs off the main actor. Every wait is on an audio call or a snapshot, and
/// the time limit only turns one that never arrives into a failure.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct CueRulesTests {
    private typealias Call = FakeAudioOutput.Call

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

    /// A hop through the fake's actor, so a call it has just begun has finished and its result is on its way
    /// back before the test does anything else.
    private func audioCallsHaveReturned() async {
        _ = await audio.history
    }

    /// Moves the clock to a time since the test began, as a single wake.
    private func advance(to seconds: Double) {
        clock.advance(by: clock.now.duration(to: at(seconds)))
    }

    // MARK: Which Cues play, and when they're handed over

    @Test func `Each Phase change gets its Cue, handed over 1.5s ahead with its deadline`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
        advance(to: 53.5)
        #expect(await calls.next() == .schedule(.work, at: at(55)))
        advance(to: 83.5)
        #expect(await calls.next() == .schedule(.cooldown, at: at(85)))
        advance(to: 143.5)
        #expect(await calls.next() == .schedule(.workoutComplete, at: at(145)))
    }

    @Test func `Every Work says Work, even directly after another Work`() async {
        let engine = makeEngine([firstWork, secondWork])
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(0)))

        advance(to: 28.5)
        #expect(await calls.next() == .schedule(.work, at: at(30)))
    }

    // MARK: Start

    @Test func `A Workout with Dip on that opens on Prepare activates undipped`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()

        await engine.start()

        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `A Workout with Dip on that opens on Work activates ducked and needs no Dip cycle`() async {
        let engine = makeEngine([firstWork], isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()

        await engine.start()

        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(0)))
    }

    @Test func `A Workout with Dip off that opens on Work activates undipped`() async {
        let engine = makeEngine([firstWork])
        var calls = audio.calls.makeAsyncIterator()

        await engine.start()

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(0)))
    }

    @Test func `The start point is set once audio is ready`() async {
        await audio.onNext(.activate(ducking: false), .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        advance(to: 0.5)
        await audio.release()
        await start.value

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(10.5)))
    }

    @Test func `Start waits at most 1s for audio, then starts with an exact timer and retries before the next Cue`()
        async
    {
        await audio.onNext(.activate(ducking: false), .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        advance(to: 1)
        await start.value

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(11)))
        advance(to: 9.5)
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(11)))
        await audio.release()
    }

    @Test func `If audio fails at Start, the Workout starts at once and retries before the next Cue`() async {
        await audio.onNext(.activate(ducking: false), .fail)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()

        await engine.start()

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(10)))
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 8.5)
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A hung audio call never holds up a Phase change`() async {
        await audio.onNext(.schedule(.work, at: at(10)), .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()

        advance(to: 10)

        #expect(await snapshots.next()?.progress == .running(phase: firstWork, endsAt: at(40)))
        await audio.release()
    }

    // MARK: Late Cues

    @Test func `A Cue exactly 1s late still plays`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()

        advance(to: 11)

        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A Cue more than 1s late is skipped, and the next Cue still plays`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()

        advance(to: 11.25)
        advance(to: 38.5)

        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A Cue whose audio is ready more than 1s late is skipped, and a Dip for it is lifted`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .hold)
        advance(to: 8.5)
        #expect(await calls.next() == .activate(ducking: true))

        advance(to: 11.25)
        await audio.release()

        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `A Cue that can't be scheduled is dropped, and the next Cue activates audio first`() async {
        await audio.onNext(.schedule(.work, at: at(10)), .fail)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        await audioCallsHaveReturned()

        advance(to: 38.5)

        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    // MARK: Dip

    @Test func `With Dip on, each Cue ducks at its lead and lifts once it has finished speaking`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 8.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(10)))

        advance(to: 11)
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 38.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A failed Dip plays its Cue undipped and tries again on the next one`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .fail)

        advance(to: 8.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(10)))

        // There's no Dip to lift, so the next call is the next Cue's Dip.
        await audio.finishSpeaking()
        advance(to: 38.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `If a Dip and the undipped fallback both fail, there's no Cue and the next one tries again`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .fail)
        await audio.onNext(.activate(ducking: false), .fail)

        advance(to: 8.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 38.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    /// Starts an engine with Dip on and moves to 11 s, with its first Cue speaking.
    private func startWithDipSpeaking(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()
        _ = await calls.next()
        advance(to: 11)
        return calls
    }

    @Test func `A failed lift retries after 5s`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.onNext(.activate(ducking: false), .fail)

        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 16)
        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `A failed lift retries only once, then waits for the next Cue`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.onNext(.activate(ducking: false), .fail)
        await audio.onNext(.activate(ducking: false), .fail)

        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 16)
        #expect(await calls.next() == .activate(ducking: false))
        await audioCallsHaveReturned()

        // The Dip was never lifted, so the next Cue needs no new one, and a third try would arrive first.
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test func `A lift retry due after the next Cue is armed doesn't lift that Cue's Dip`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.onNext(.activate(ducking: false), .fail)
        advance(to: 36)
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
        await audioCallsHaveReturned()
        // Reaching the next Cue through its own lead is what would cancel the retry due at 41 s.
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))

        advance(to: 41)
        await audio.finishSpeaking()

        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 53.5)
        #expect(await calls.next() == .activate(ducking: true))
    }

    @Test func `A finish reported for an earlier Cue lifts nothing`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
        let firstCue = await audio.tokens[0]
        advance(to: 38.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(40)))

        audio.send(.cueFinished(firstCue))
        await audio.finishSpeaking()

        // One lift, for the current Cue. Then the next Cue's Dip follows it directly.
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 53.5)
        #expect(await calls.next() == .activate(ducking: true))
    }

    @Test func `Armed Cues each carry their own token`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()
        advance(to: 38.5)
        _ = await calls.next()

        let tokens = await audio.tokens

        #expect(tokens.count == 2)
        #expect(Set(tokens).count == 2)
    }

    // MARK: Pause

    @Test func `A Cue isn't handed over before its lead`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.25)

        await engine.pause(at: clock.now)

        // Had a Cue been handed over, it would arrive ahead of the release, with a cancel for it.
        #expect(await calls.next() == .deactivate)
    }

    @Test func `Pause between Cues releases the session, and Resume restarts it undipped`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 4)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 104)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 108.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(110)))
    }

    @Test func `A paused Workout hands over no Cues`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 4)
        await engine.pause(at: clock.now)
        _ = await calls.next()

        advance(to: 1_000)
        await engine.resume(at: clock.now)

        #expect(await calls.next() == .activate(ducking: false))
    }

    @Test(arguments: [true, false])
    func `Pause during the lead cancels the Cue, and Resume under 1.5s out restarts at once and reschedules it`(
        isDipOn: Bool
    ) async {
        let engine = makeEngine(isDipOn: isDipOn)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        if isDipOn {
            _ = await calls.next()
        }
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        advance(to: 9)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)

        advance(to: 109)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: isDipOn))
        #expect(await calls.next() == .schedule(.work, at: at(110)))
    }

    @Test func `A Pause tapped before the deadline schedules the Cue again, however late the engine hears of it`() async
    {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 9.75)
        _ = await calls.next()
        let tap = clock.now
        advance(to: 10.25)

        await engine.pause(at: tap)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)

        advance(to: 110.25)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(110.5)))
    }

    @Test func `Pause during a Cue cuts it, and Resume doesn't repeat it`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)

        advance(to: 111)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: false))

        advance(to: 138.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.rest, at: at(140)))
    }

    @Test func `Pause after a Cue has finished has nothing to cut`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))

        await engine.pause(at: clock.now)

        #expect(await calls.next() == .deactivate)
    }

    @Test func `A lift retry doesn't run during a Pause`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = await startWithDipSpeaking(engine)
        await audio.onNext(.activate(ducking: false), .fail)
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
        await audioCallsHaveReturned()
        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 16)
        await engine.resume(at: clock.now)

        // Resume's own restart with no retry ahead of it, then the next Cue with no lift in between.
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 43.5)
        #expect(await calls.next() == .activate(ducking: true))
    }

    // MARK: Old tokens

    @Test func `An activate that returns after a Pause schedules nothing`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .hold)
        advance(to: 8.5)
        _ = await calls.next()

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
        await audio.release()

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `An activate that fails after a Pause has no fallback`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .hold)
        advance(to: 8.5)
        _ = await calls.next()

        await engine.pause(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()
        await audio.release(failing: true)
        await audioCallsHaveReturned()

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: true))
    }

    @Test func `A schedule that fails after a Pause lifts nothing`() async {
        let engine = makeEngine(isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.schedule(.work, at: at(10)), .hold)
        advance(to: 8.5)
        _ = await calls.next()
        _ = await calls.next()

        await engine.pause(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()
        await audio.release(failing: true)
        await audioCallsHaveReturned()

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate(ducking: true))
    }

    @Test func `A finish reported for a cut Cue doesn't count for the Cue armed after it`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 9)
        _ = await calls.next()
        let cutCue = await audio.tokens[0]
        await engine.pause(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()
        await engine.resume(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()

        audio.send(.cueFinished(cutCue))
        await engine.pause(at: clock.now)

        // The current Cue is still armed, so it needs cutting.
        #expect(await calls.next() == .cancel)
    }

    // MARK: Stop

    @Test func `Stop cuts an armed Cue and releases the session`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 10.5)
        _ = await calls.next()

        await engine.stop()

        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
    }

    @Test func `Stop between Cues releases the session, and no Cue follows`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 4)

        await engine.stop()
        #expect(await calls.next() == .deactivate)

        advance(to: 1_000)
        await audioCallsHaveReturned()
        #expect(await audio.history == [.activate(ducking: false), .deactivate])
    }

    @Test func `Stop during a Pause has no session to release`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await engine.pause(at: clock.now)
        _ = await calls.next()

        await engine.stop()

        await audioCallsHaveReturned()
        #expect(await audio.history == [.activate(ducking: false), .deactivate])
    }

    @Test func `Stop before Start touches no audio`() async {
        let engine = makeEngine()

        await engine.stop()

        #expect(await audio.history.isEmpty)
    }

    @Test func `Stop while waiting for audio at Start ends the Workout with no Phase, and releases the session`() async
    {
        await audio.onNext(.activate(ducking: false), .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        await engine.stop()
        await start.value

        #expect(await snapshots.next()?.progress == .stopped)
        #expect(await snapshots.next() == nil)
        #expect(await calls.next() == .deactivate)
        await audio.release()
    }

    @Test func `A schedule that returns after Stop does nothing more`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.schedule(.work, at: at(10)), .hold)
        advance(to: 8.5)
        _ = await calls.next()

        await engine.stop()
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
        await audio.release(failing: true)
        await audioCallsHaveReturned()

        #expect(await audio.history.count == 4)
    }

    // MARK: Workout complete

    /// Starts a single-Work Workout and hands over "Workout complete", due at 30 s.
    private func startToCompleteLead(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate(ducking: false))
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 28.5)
        #expect(await calls.next() == .schedule(.workoutComplete, at: at(30)))
        return calls
    }

    /// Runs a single-Work Workout to its finish, with "Workout complete" speaking. The engine goes when this
    /// returns, as it does when the complete screen is left.
    private func finishAndDropEngine() async -> AsyncStream<Call>.Iterator {
        let engine = makeEngine([firstWork])
        let calls = await startToCompleteLead(engine)
        var snapshots = engine.snapshots.makeAsyncIterator()
        _ = await snapshots.next()
        advance(to: 30)
        #expect(await snapshots.next()?.progress == .finished)
        return calls
    }

    @Test func `"Workout complete" holds the session until its speech ends`() async {
        let engine = makeEngine([firstWork])
        var calls = await startToCompleteLead(engine)
        var snapshots = engine.snapshots.makeAsyncIterator()
        _ = await snapshots.next()

        advance(to: 30)
        #expect(await snapshots.next()?.progress == .finished)
        #expect(await snapshots.next() == nil)
        await audioCallsHaveReturned()
        #expect(await audio.history.contains(.deactivate) == false)

        await audio.finishSpeaking()
        #expect(await calls.next() == .deactivate)
    }

    @Test func `"Workout complete" holds the session even after the complete screen has gone`() async {
        var calls = await finishAndDropEngine()

        await audio.finishSpeaking()

        #expect(await calls.next() == .deactivate)
    }

    @Test func `With Dip on, "Workout complete" stays ducked until the session is released`() async {
        let engine = makeEngine([firstWork], isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        #expect(await calls.next() == .activate(ducking: false))
        advance(to: 28.5)
        #expect(await calls.next() == .activate(ducking: true))
        #expect(await calls.next() == .schedule(.workoutComplete, at: at(30)))
        _ = await snapshots.next()
        advance(to: 30)
        _ = await snapshots.next()

        await audio.finishSpeaking()

        #expect(await calls.next() == .deactivate)
    }

    @Test func `A finish that arrives ahead of the Workout's end releases the session at the end`() async {
        let engine = makeEngine([firstWork])
        var calls = await startToCompleteLead(engine)
        await audio.finishSpeaking()
        await audioCallsHaveReturned()

        advance(to: 30)

        #expect(await calls.next() == .deactivate)
    }

    @Test func `A Workout that finishes up to 1s late still says "Workout complete"`() async {
        let engine = makeEngine([firstWork])
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        _ = await calls.next()

        advance(to: 30.5)

        #expect(await calls.next() == .schedule(.workoutComplete, at: at(30)))
    }

    @Test func `A Workout that finished in the background has no late "Workout complete" and releases the session`()
        async
    {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()

        advance(to: 1_000)

        #expect(await calls.next() == .deactivate)
    }

    @Test func `If "Workout complete" fails after the finish, the session is released`() async {
        let engine = makeEngine([firstWork])
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        _ = await calls.next()
        _ = await calls.next()
        await audio.onNext(.schedule(.workoutComplete, at: at(30)), .hold)
        advance(to: 28.5)
        _ = await calls.next()
        advance(to: 30)
        #expect(await snapshots.next()?.progress == .finished)

        await audio.release(failing: true)

        #expect(await calls.next() == .deactivate)
    }

    @Test func `If audio for "Workout complete" is ready more than 1s late, it's skipped and the session released`()
        async
    {
        let engine = makeEngine([firstWork], isDipOn: true)
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        _ = await calls.next()
        _ = await calls.next()
        await audio.finishSpeaking()
        _ = await calls.next()
        await audio.onNext(.activate(ducking: true), .hold)
        advance(to: 28.5)
        _ = await calls.next()
        advance(to: 31.25)
        #expect(await snapshots.next()?.progress == .finished)

        await audio.release()

        #expect(await calls.next() == .deactivate)
    }

    @Test func `The session is released only once, whatever is reported after`() async {
        let engine = makeEngine([firstWork])
        var calls = await startToCompleteLead(engine)
        var snapshots = engine.snapshots.makeAsyncIterator()
        _ = await snapshots.next()
        advance(to: 30)
        _ = await snapshots.next()
        await audio.finishSpeaking()
        #expect(await calls.next() == .deactivate)

        await audio.finishSpeaking()
        await engine.stop()
        await audioCallsHaveReturned()

        #expect(await audio.history.filter { $0 == .deactivate }.count == 1)
    }
}
