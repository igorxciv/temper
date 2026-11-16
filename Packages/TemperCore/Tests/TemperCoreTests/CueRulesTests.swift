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
    private func makeEngine() -> WorkoutEngine<ManualClock> {
        makeEngine([prepare, firstWork, rest, secondWork, cooldown])
    }

    private func makeEngine(_ phases: [Phase]) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: Workout(phases: phases), clock: clock, audio: audio)
    }

    private func at(_ seconds: Double) -> ManualClock.Instant {
        ManualClock.Instant(offset: .seconds(seconds))
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

    // MARK: Which Cues play, and when they're handed over

    @Test func `Each Phase change gets its Cue, handed over 1.5s ahead with its deadline`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)

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

    /// The Cue rules check lateness before handing a Cue over, but audio can take a while to start after that,
    /// so audio is told the latest start too.
    @Test func `A Cue is handed over with its latest start, 1s after its deadline`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)

        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        #expect(await audio.latestStarts == [at(11)])
    }

    // MARK: Exercises

    @Test func `The Rest before a named Work says it's next, and a Workout opening on a named Work says it at once`()
        async
    {
        let squats = Phase(kind: .work, duration: .seconds(30), round: 1, exercise: Exercise("Squats"))
        let pushUps = Phase(kind: .work, duration: .seconds(30), round: 2, exercise: Exercise("Push-ups"))
        let engine = makeEngine([squats, rest, pushUps])
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))

        advance(to: 28.5)
        #expect(await calls.next() == .schedule(.rest, at: at(30)))
        advance(to: 43.5)
        #expect(await calls.next() == .schedule(.work, at: at(45)))

        #expect(await audio.exercises == [Exercise("Squats"), Exercise("Push-ups"), nil])
    }

    @Test func `A Prepare before a named Work says it's next at Start, and the Work then says only Work`() async {
        let squats = Phase(kind: .work, duration: .seconds(30), round: 1, exercise: Exercise("Squats"))
        let engine = makeEngine([prepare, squats])
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.prepare, at: at(0)))

        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        #expect(await audio.exercises == [Exercise("Squats"), nil])
    }

    @Test func `Every Work says Work, even directly after another Work`() async {
        let engine = makeEngine([firstWork, secondWork])
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))

        advance(to: 28.5)
        #expect(await calls.next() == .schedule(.work, at: at(30)))
    }

    @Test func `A Stopwatch says Work as its Work starts and Finish at its length, and nothing at Done`() async {
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        let engine = WorkoutEngine(workout: workout, clock: clock, audio: audio)
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        _ = await snapshots.next()

        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        await audio.finishSpeaking()
        advance(to: 608.5)
        #expect(await calls.next() == .schedule(.finish, at: at(610)))
        advance(to: 610)
        #expect(await snapshots.next()?.phase?.kind == .work)
        #expect(await snapshots.next()?.progress == .runningOpen(phase: workout.phases[1], startedAt: at(10)))
        await audio.finishSpeaking()

        advance(to: 900)
        await engine.done(at: at(900))
        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await calls.next() == .deactivate)
        await letAudioSettle()

        let expected: [Call] = [
            .activate,
            .schedule(.work, at: at(10)),
            .schedule(.finish, at: at(610)),
            .deactivate,
        ]
        #expect(await audio.history == expected)
    }

    // MARK: Start

    @Test func `A Workout that opens on Work activates and says Work at zero`() async {
        let engine = makeEngine([firstWork])
        var calls = audio.calls.makeAsyncIterator()

        await engine.start()

        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
    }

    @Test func `The start point is set once audio is ready`() async {
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        advance(to: 0.5)
        await audio.release()
        _ = await start.value

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(10.5)))
    }

    @Test func `Start waits at most 1s for audio, then starts with an exact timer and retries before the next Cue`()
        async
    {
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        advance(to: 1)
        _ = await start.value

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(11)))
        advance(to: 9.5)
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(11)))
        await audio.release()
    }

    @Test func `If audio fails at Start, the Workout starts at once and retries before the next Cue`() async {
        await audio.onNext(.activate, .fail)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()

        await engine.start()

        #expect(await snapshots.next()?.progress == .running(phase: prepare, endsAt: at(10)))
        #expect(await calls.next() == .activate)
        advance(to: 8.5)
        #expect(await calls.next() == .activate)
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
        await letAudioSettle()
        advance(to: 38.5)

        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A Cue whose audio is ready more than 1s late is skipped, and the next Cue still plays`() async {
        // A failed Start leaves no session, so the first Cue activates audio first.
        await audio.onNext(.activate, .fail)
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        #expect(await calls.next() == .activate)

        advance(to: 11.25)
        await audio.release()
        await letAudioSettle()
        advance(to: 38.5)

        // The skipped "Work" Cue would come ahead of this.
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    @Test func `A Cue that can't be scheduled is dropped, and the next Cue activates audio first`() async {
        await audio.onNext(.schedule(.work, at: at(10)), .fail)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        await letAudioSettle()

        advance(to: 38.5)

        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    // MARK: Activating for a Cue

    @Test func `If audio can't be activated for a Cue, there's no Cue and the next one tries again`() async {
        await audio.onNext(.activate, .fail)
        await audio.onNext(.activate, .fail)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()

        advance(to: 8.5)
        #expect(await calls.next() == .activate)
        await letAudioSettle()

        advance(to: 38.5)
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
    }

    /// Starts an engine and moves to 11 s, with its first Cue speaking.
    private func startWithCueSpeaking(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()
        advance(to: 11)
        return calls
    }

    @Test func `A finish reported for an earlier Cue doesn't end the current one`() async {
        let engine = makeEngine()
        var calls = await startWithCueSpeaking(engine)
        await audio.finishSpeaking()
        let firstCue = await audio.tokens[0]
        advance(to: 38.5)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))

        audio.send(.cueFinished(firstCue))
        await letAudioSettle()
        await engine.pause(at: clock.now)

        // The current Cue is still armed, so it needs cutting.
        #expect(await calls.next() == .cancel)
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

    @Test func `Pause between Cues releases the session, and Resume restarts it`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 4)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 104)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 108.5)
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

        #expect(await calls.next() == .activate)
    }

    @Test func `Pause during the lead cancels the Cue, and Resume under 1.5s out restarts at once and reschedules it`()
        async
    {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        advance(to: 9)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)

        advance(to: 109)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)
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
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(110.5)))
    }

    @Test func `Pause during a Cue cuts it, and Resume doesn't repeat it`() async {
        let engine = makeEngine()
        var calls = await startWithCueSpeaking(engine)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)

        advance(to: 111)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 138.5)
        #expect(await calls.next() == .schedule(.rest, at: at(140)))
    }

    @Test func `Pause after a Cue has finished has nothing to cut`() async {
        let engine = makeEngine()
        var calls = await startWithCueSpeaking(engine)
        await audio.finishSpeaking()
        await letAudioSettle()

        await engine.pause(at: clock.now)

        #expect(await calls.next() == .deactivate)
    }

    // MARK: Old tokens

    @Test func `An activate that returns after a Pause schedules nothing`() async {
        // A failed Start leaves no session, so the first Cue activates audio first.
        await audio.onNext(.activate, .fail)
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
        await audio.release()
        await letAudioSettle()

        // A Pause of 100 s gives the new Cue a different deadline, so the old one can't pass for it.
        advance(to: 108.5)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(110)))
    }

    @Test func `An activate that fails after a Pause does nothing to the Cue armed since`() async {
        await audio.onNext(.activate, .fail)
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 8.5)
        _ = await calls.next()

        await engine.pause(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()
        await audio.release(failing: true)
        await letAudioSettle()

        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }

    @Test func `A schedule that fails after a Pause does nothing to the Cue armed since`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await audio.onNext(.schedule(.work, at: at(10)), .hold)
        advance(to: 8.5)
        _ = await calls.next()
        await engine.pause(at: clock.now)
        _ = await calls.next()
        _ = await calls.next()
        advance(to: 108.5)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(110)))

        await audio.release(failing: true)
        await letAudioSettle()
        await engine.pause(at: clock.now)

        // The new Cue is still armed, so it needs cutting.
        #expect(await calls.next() == .cancel)
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
        await letAudioSettle()
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

        await engine.stop(at: clock.now)

        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
    }

    @Test func `Stop between Cues releases the session, and no Cue follows`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        advance(to: 4)

        await engine.stop(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 1_000)
        await letAudioSettle()
        #expect(await audio.history == [.activate, .deactivate])
    }

    @Test func `Stop during a Pause has no session to release`() async {
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        await engine.pause(at: clock.now)
        _ = await calls.next()

        await engine.stop(at: clock.now)

        await letAudioSettle()
        #expect(await audio.history == [.activate, .deactivate])
    }

    @Test func `Stop before Start touches no audio`() async {
        let engine = makeEngine()

        await engine.stop(at: clock.now)

        #expect(await audio.history.isEmpty)
    }

    @Test func `Stop while waiting for audio at Start ends the Workout with no Phase, and releases the session`() async
    {
        await audio.onNext(.activate, .hold)
        let engine = makeEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        let start = Task { await engine.start() }
        _ = await calls.next()

        await engine.stop(at: clock.now)
        #expect(await start.value == nil)

        #expect(await snapshots.next()?.wasStopped == true)
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

        await engine.stop(at: clock.now)
        #expect(await calls.next() == .cancel)
        #expect(await calls.next() == .deactivate)
        await audio.release(failing: true)
        await letAudioSettle()

        #expect(await audio.history.count == 4)
    }

    // MARK: Workout complete

    /// Starts a single-Work Workout and hands over "Workout complete", due at 30 s.
    private func startToCompleteLead(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
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
        #expect(await snapshots.next()?.hasFinished == true)
        return calls
    }

    @Test func `"Workout complete" holds the session until its speech ends`() async {
        let engine = makeEngine([firstWork])
        var calls = await startToCompleteLead(engine)
        var snapshots = engine.snapshots.makeAsyncIterator()
        _ = await snapshots.next()

        advance(to: 30)
        #expect(await snapshots.next()?.hasFinished == true)
        #expect(await snapshots.next() == nil)
        await letAudioSettle()
        #expect(await audio.history.contains(.deactivate) == false)

        await audio.finishSpeaking()
        #expect(await calls.next() == .deactivate)
    }

    @Test func `"Workout complete" holds the session even after the complete screen has gone`() async {
        var calls = await finishAndDropEngine()

        await audio.finishSpeaking()

        #expect(await calls.next() == .deactivate)
    }

    @Test func `A finish that arrives ahead of the Workout's end releases the session at the end`() async {
        let engine = makeEngine([firstWork])
        var calls = await startToCompleteLead(engine)
        await audio.finishSpeaking()
        await letAudioSettle()

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
        #expect(await snapshots.next()?.hasFinished == true)

        await audio.release(failing: true)

        #expect(await calls.next() == .deactivate)
    }

    @Test func `If audio for "Workout complete" is ready more than 1s late, it's skipped and the session released`()
        async
    {
        // A failed "Work" leaves no session, so "Workout complete" activates audio first.
        await audio.onNext(.schedule(.work, at: at(0)), .fail)
        let engine = makeEngine([firstWork])
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        _ = await snapshots.next()
        _ = await calls.next()
        _ = await calls.next()
        await letAudioSettle()
        await audio.onNext(.activate, .hold)
        advance(to: 28.5)
        #expect(await calls.next() == .activate)
        advance(to: 31.25)
        #expect(await snapshots.next()?.hasFinished == true)

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
        await engine.stop(at: clock.now)
        await letAudioSettle()

        #expect(await audio.history.filter { $0 == .deactivate }.count == 1)
    }

    // MARK: Done

    private let openWork = Phase(kind: .work, length: .open, round: 1)
    private let doneRest = Phase(kind: .rest, duration: .seconds(30), round: 1)
    private let lastWork = Phase(kind: .work, duration: .seconds(30), round: 2)

    /// An open Work, then a Rest of 0:30, then a Work of 0:30. The "Work" Cue is due at 0.
    private func makeDoneEngine() -> WorkoutEngine<ManualClock> {
        makeEngine([openWork, doneRest, lastWork])
    }

    @Test func `An open Work with no Done sends nothing to audio until Stop`() async {
        let engine = makeDoneEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()

        advance(to: 10_000)
        await letAudioSettle()
        #expect(await audio.history == [.activate, .schedule(.work, at: at(0))])

        await engine.stop(at: clock.now)
        #expect(await calls.next() == .deactivate)
    }

    @Test func `Done hands over the "Rest" Cue due at the tap, and the next Cue 1.5s ahead of the Rest's end`() async {
        let engine = makeDoneEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 40)
        let tap = clock.now

        clock.advanceWhileSuspended(by: .milliseconds(500))
        await engine.done(at: tap)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
        #expect(await audio.latestStarts.last == at(41))

        await audio.finishSpeaking()
        advance(to: 68.5)
        #expect(await calls.next() == .schedule(.work, at: at(70)))
    }

    @Test func `A "Rest" Cue on Done heard of over 1s after the tap is skipped, and the next Cue still plays`() async {
        let engine = makeDoneEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 40)
        let tap = clock.now

        clock.advanceWhileSuspended(by: .milliseconds(1_250))
        await engine.done(at: tap)
        await letAudioSettle()
        advance(to: 68.5)

        // The skipped "Rest" Cue would come ahead of this.
        #expect(await calls.next() == .schedule(.work, at: at(70)))
    }

    @Test func `A "Rest" Cue on Done whose audio is ready more than 1s after the tap is skipped`() async {
        // A failed "Work" leaves no session, so the "Rest" Cue activates audio first.
        await audio.onNext(.schedule(.work, at: at(0)), .fail)
        let engine = makeDoneEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await letAudioSettle()
        await audio.onNext(.activate, .hold)
        advance(to: 40)

        await engine.done(at: clock.now)
        #expect(await calls.next() == .activate)
        advance(to: 41.25)
        await audio.release()
        await letAudioSettle()

        // The skipped "Rest" Cue would come ahead of this.
        advance(to: 68.5)
        #expect(await calls.next() == .schedule(.work, at: at(70)))
    }

    /// Starts an open Work and lets its "Work" Cue finish.
    private func startOpenWorkAfterItsCue(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        _ = await calls.next()
        _ = await calls.next()
        await audio.finishSpeaking()
        await letAudioSettle()
        return calls
    }

    @Test func `Pause in an open Work releases the session, and a Done while Paused sends nothing to audio`() async {
        let engine = makeDoneEngine()
        var calls = await startOpenWorkAfterItsCue(engine)
        advance(to: 20)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 50)
        await engine.done(at: clock.now)
        await letAudioSettle()

        #expect(await audio.history == [.activate, .schedule(.work, at: at(0)), .deactivate])
    }

    @Test func `Resume in an open Work restarts audio with no Cue upcoming, and a later Done brings "Rest" at the tap`()
        async
    {
        let engine = makeDoneEngine()
        var calls = await startOpenWorkAfterItsCue(engine)
        advance(to: 20)
        await engine.pause(at: clock.now)
        _ = await calls.next()

        advance(to: 60)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 10_000)
        await letAudioSettle()
        #expect(await audio.history == [.activate, .schedule(.work, at: at(0)), .deactivate, .activate])

        await engine.done(at: clock.now)
        #expect(await calls.next() == .schedule(.rest, at: at(10_000)))
        #expect(await audio.latestStarts.last == at(10_001))

        await audio.finishSpeaking()
        advance(to: 10_028.5)
        #expect(await calls.next() == .schedule(.work, at: at(10_030)))
    }

    @Test
    func `Pause in the Rest after Done releases the session, and Resume hands over the next Cue at its shifted end`()
        async
    {
        let engine = makeDoneEngine()
        var calls = await startOpenWorkAfterItsCue(engine)
        advance(to: 40)
        await engine.done(at: clock.now)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
        await audio.finishSpeaking()
        await letAudioSettle()
        advance(to: 50)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)

        advance(to: 150)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 168.5)
        #expect(await calls.next() == .schedule(.work, at: at(170)))
    }
}

// MARK: Open Rounds

/// The Cues of Open Rounds: "Work" as each Round's open Work starts, "Rest" at Done, "10 seconds" before a Rest
/// ends, and nothing on Stop. `nonisolated` like the suite.
nonisolated extension CueRulesTests {
    /// Open Rounds with a Rest of `rest` seconds.
    private func makeOpenRoundsEngine(rest: Int = 60) -> WorkoutEngine<ManualClock> {
        var settings = WorkoutType.openRounds.firstLaunch
        settings[.rest] = rest
        let workout = WorkoutType.openRounds.makeWorkout(from: settings)
        return WorkoutEngine(workout: workout, clock: clock, audio: audio)
    }

    @Test func `Open Rounds activates and says Work at zero, with no Prepare`() async {
        let engine = makeOpenRoundsEngine()
        var calls = audio.calls.makeAsyncIterator()

        await engine.start()

        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
    }

    @Test func `Done says Rest, then "10 seconds" and the next Work's Cue, each handed over 1.5s ahead`() async {
        let engine = makeOpenRoundsEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))

        for round in 0..<3 {
            let roundStart = Double(round) * 100
            await audio.finishSpeaking()
            advance(to: roundStart + 40)
            await engine.done(at: clock.now)
            #expect(await calls.next() == .schedule(.rest, at: at(roundStart + 40)))

            await audio.finishSpeaking()
            advance(to: roundStart + 88.5)
            #expect(await calls.next() == .schedule(.tenSeconds, at: at(roundStart + 90)))

            await audio.finishSpeaking()
            advance(to: roundStart + 98.5)
            #expect(await calls.next() == .schedule(.work, at: at(roundStart + 100)))
        }
    }

    @Test func `With a Rest of zero, Done says Work`() async {
        let engine = makeOpenRoundsEngine(rest: 0)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 40)

        await engine.done(at: clock.now)

        #expect(await calls.next() == .schedule(.work, at: at(40)))
    }

    @Test(arguments: [false, true])
    func `Stop ends Open Rounds with no Workout complete Cue`(duringRest: Bool) async {
        let engine = makeOpenRoundsEngine()
        var calls = audio.calls.makeAsyncIterator()
        var snapshots = engine.snapshots.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 40)
        if duringRest {
            await engine.done(at: clock.now)
            #expect(await calls.next() == .schedule(.rest, at: at(40)))
            await audio.finishSpeaking()
            advance(to: 70)
        }

        await engine.stop(at: clock.now)
        await letAudioSettle()

        var last: WorkoutSnapshot<ManualClock.Instant>?
        while let snapshot = await snapshots.next() { last = snapshot }
        #expect(last?.wasStopped == true)
        #expect(await audio.history.last == .deactivate)
        #expect(await !audio.history.contains { if case .schedule(.workoutComplete, _) = $0 { true } else { false } })
    }
}

// MARK: The "10 seconds" Cue

/// "10 seconds" before an Open Rounds Rest ends, handed over like every other Cue. `nonisolated` like the suite.
nonisolated extension CueRulesTests {
    /// Starts an Open Rounds engine and marks Round 1's Work Done at 40 s once "Work" has spoken, then returns the
    /// calls that follow as "Rest" finishes speaking.
    private func startToRest(_ engine: WorkoutEngine<ManualClock>) async -> AsyncStream<Call>.Iterator {
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.work, at: at(0)))
        await audio.finishSpeaking()
        advance(to: 40)
        await engine.done(at: clock.now)
        #expect(await calls.next() == .schedule(.rest, at: at(40)))
        await audio.finishSpeaking()
        await letAudioSettle()
        return calls
    }

    @Test(arguments: [20, 60, 1800])
    func `An Open Rounds Rest of 00:20 or more says "10 seconds" 10s before it ends`(rest: Int) async {
        let engine = makeOpenRoundsEngine(rest: rest)
        var calls = await startToRest(engine)
        let restEnd = 40 + Double(rest)

        advance(to: restEnd - 11.5)
        #expect(await calls.next() == .schedule(.tenSeconds, at: at(restEnd - 10)))

        await audio.finishSpeaking()
        advance(to: restEnd - 1.5)
        #expect(await calls.next() == .schedule(.work, at: at(restEnd)))
    }

    @Test func `An Open Rounds Rest under 00:20 has no "10 seconds"`() async {
        let engine = makeOpenRoundsEngine(rest: 15)
        var calls = await startToRest(engine)

        // A "10 seconds" due at 45 s would be handed over here.
        advance(to: 43.5)
        await letAudioSettle()
        advance(to: 53.5)

        #expect(await calls.next() == .schedule(.work, at: at(55)))
    }

    @Test func `Intervals has no "10 seconds", however long its Rest`() async {
        var settings = WorkoutType.intervals.firstLaunch
        settings[.rest] = 60
        let workout = WorkoutType.intervals.makeWorkout(from: settings)
        let engine = WorkoutEngine(workout: workout, clock: clock, audio: audio)
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
        await audio.finishSpeaking()
        advance(to: 48.5)
        #expect(await calls.next() == .schedule(.rest, at: at(50)))
        await audio.finishSpeaking()

        // Round 1's Rest ends at 110 s, so a "10 seconds" due at 100 s would be handed over here.
        advance(to: 98.5)
        await letAudioSettle()
        advance(to: 108.5)

        #expect(await calls.next() == .schedule(.work, at: at(110)))
    }

    @Test func `A Pause before "10 seconds" moves it with the Rest`() async {
        let engine = makeOpenRoundsEngine()
        var calls = await startToRest(engine)
        advance(to: 60)

        await engine.pause(at: clock.now)
        #expect(await calls.next() == .deactivate)
        advance(to: 160)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 188.5)
        #expect(await calls.next() == .schedule(.tenSeconds, at: at(190)))
        await audio.finishSpeaking()
        advance(to: 198.5)
        #expect(await calls.next() == .schedule(.work, at: at(200)))
    }

    @Test(arguments: [false, true])
    func `A Pause in the Rest's last 10s doesn't repeat "10 seconds" on Resume`(hasFinishedSpeaking: Bool) async {
        let engine = makeOpenRoundsEngine()
        var calls = await startToRest(engine)
        advance(to: 88.5)
        #expect(await calls.next() == .schedule(.tenSeconds, at: at(90)))
        advance(to: 91)
        if hasFinishedSpeaking {
            await audio.finishSpeaking()
            await letAudioSettle()
        }

        await engine.pause(at: clock.now)
        if !hasFinishedSpeaking {
            #expect(await calls.next() == .cancel)
        }
        #expect(await calls.next() == .deactivate)
        advance(to: 191)
        await engine.resume(at: clock.now)
        #expect(await calls.next() == .activate)

        advance(to: 198.5)
        #expect(await calls.next() == .schedule(.work, at: at(200)))
    }

    @Test func `A "10 seconds" more than 1s late is skipped, and the next Work's Cue still plays`() async {
        let engine = makeOpenRoundsEngine()
        var calls = await startToRest(engine)

        advance(to: 91.25)
        await letAudioSettle()
        advance(to: 98.5)

        #expect(await calls.next() == .schedule(.work, at: at(100)))
    }

    @Test func `A "10 seconds" interrupted before its deadline is scheduled again on recovery up to 1s after it`()
        async
    {
        let engine = makeOpenRoundsEngine()
        var calls = await startToRest(engine)
        advance(to: 88.5)
        #expect(await calls.next() == .schedule(.tenSeconds, at: at(90)))
        advance(to: 89)
        audio.send(.interrupted)
        #expect(await calls.next() == .cancel)

        advance(to: 90.5)
        audio.send(.resumeRecommended)

        #expect(await calls.next() == .activate)
        #expect(await calls.next() == .schedule(.tenSeconds, at: at(90)))
    }
}

// MARK: The Countdown

/// The Countdown, handed over like every other Cue. `nonisolated` like the suite.
nonisolated extension CueRulesTests {
    /// A Prepare and a Work that count down, with the Countdowns due at 5 and 35 s.
    private func makeCountingDownEngine() -> WorkoutEngine<ManualClock> {
        let workout = Workout(phases: [prepare, firstWork], countsDown: true)
        return WorkoutEngine(workout: workout, clock: clock, audio: audio)
    }

    @Test func `The Countdown is handed over 1.5s ahead, and the Phase's Cue after it`() async {
        let engine = makeCountingDownEngine()
        var calls = audio.calls.makeAsyncIterator()
        await engine.start()
        #expect(await calls.next() == .activate)

        advance(to: 3.5)
        #expect(await calls.next() == .schedule(.countdown, at: at(5)))
        advance(to: 8.5)
        #expect(await calls.next() == .schedule(.work, at: at(10)))
    }
}
