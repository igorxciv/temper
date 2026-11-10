import Foundation
import Testing

@testable import TemperCore

/// A whole Workout of each Workout Type, run by the engine on the iPhone, followed on the Watch: every snapshot goes
/// through `PhoneFlow`, and every message it sends goes into `WatchFlow`.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct RunningLinkTests {
    private typealias Instant = ManualClock.Instant

    /// The two flows joined as the mirrored session joins them, with one Watch session, numbered 1.
    private struct Link {
        let workoutType: WorkoutType
        let workout: Workout
        /// The wall clock at the engine clock's zero.
        let epoch = Date(timeIntervalSinceReferenceDate: 1_000_000)

        var phone = PhoneFlow<Int, Instant>()
        var watch = WatchFlow()
        var watchEffects: [WatchFlow.Effect] = []
        /// What the Watch showed, each change once.
        var screens: [String] = []
        var isWatchOpening = false

        init(_ workoutType: WorkoutType, _ workout: Workout) {
            self.workoutType = workoutType
            self.workout = workout
        }

        func date(of instant: Instant) -> Date {
            ClockAnchor(instant: Instant(offset: .zero), date: epoch).date(of: instant)
        }

        mutating func started(at start: Instant) {
            route(
                phone.handle(
                    .started(workoutID: UUID(), workoutType: workoutType, start: date(of: start), workoutsAllowed: true)
                ))
        }

        /// The Watch's session reaches the iPhone, mirrored.
        mutating func watchArrives(at now: Instant) {
            #expect(isWatchOpening)
            route(phone.handle(.instanceArrived(1, start: date(of: now), at: date(of: now))))
        }

        /// The iPhone publishes the state of `snapshot`, and the Watch draws what it's sent.
        mutating func publish(_ snapshot: WorkoutSnapshot<Instant>, at now: Instant) {
            let display = RunningDisplay(workoutType: workoutType, workout: workout, snapshot: snapshot)
            route(phone.handle(.published(display.watchState(at: now, date: date(of: now)))))
            if case .running(let phase) = watch.screen {
                // The Watch keeps up: it draws the same time as the iPhone's ring.
                let later = now.advanced(by: .seconds(2.5))
                #expect(phase.time(at: date(of: now)) == display.ring(at: now).time)
                #expect(phase.time(at: date(of: later)) == display.ring(at: later).time)
            }
        }

        mutating func tapDone() {
            watchHandles(.doneTapped)
        }

        /// The owner taps the Watch at `tap`, and what it sends reaches the iPhone at `arrival`. Returns the commands
        /// the iPhone gives the engine, at their placed instants.
        mutating func watchTaps(
            _ command: WatchCommand, at tap: Instant, arrivingAt arrival: Instant
        ) -> [(WatchCommand, Instant)] {
            let sent = watch.handle(.tapped(command, at: date(of: tap)))
            watchEffects += sent
            for case .send(let message) in sent {
                // Through JSON, as over the session.
                route(
                    phone.handle(
                        .received(
                            try! MessageFromWatch(json: message.json()), from: 1,
                            arrival: ClockAnchor(instant: arrival, date: date(of: arrival)))))
            }
            defer { commands = [] }
            return commands
        }

        /// What the iPhone gave the engine since the last tap.
        private var commands: [(WatchCommand, Instant)] = []

        private mutating func route(_ effects: [PhoneFlow<Int, Instant>.Effect]) {
            for effect in effects {
                switch effect {
                case .startWatchApp:
                    isWatchOpening = true
                    watchHandles(.launched(workoutsAllowed: true))
                case .send(let message, to: 1):
                    // Through JSON, as over the session.
                    watchHandles(.received(try! MessageToWatch(json: message.json())))
                case .stopActivity(1):
                    watchHandles(.sessionStopped)
                    watchHandles(.sessionEnded)
                    route(phone.handle(.instanceEnded(1)))
                case .apply(let command, let placed):
                    commands.append((command, placed))
                case .send, .stopActivity:
                    Issue.record("An effect for a session that doesn't exist: \(effect)")
                }
            }
        }

        private mutating func watchHandles(_ event: WatchFlow.Event) {
            watchEffects += watch.handle(event)
            let screen = describe(watch.screen)
            if screens.last != screen {
                screens.append(screen)
            }
        }

        private func describe(_ screen: WatchFlow.Screen) -> String {
            switch screen {
            case .idle: "idle"
            case .waiting: "waiting"
            case .updateNeeded: "update needed"
            case .running(let phase):
                [
                    phase.kind.name, phase.round.map(String.init), phase.pausedAt == nil ? nil : "paused", "·",
                    "\(phase.capsule)",
                ]
                .compactMap(\.self).joined(separator: " ")
            case .complete(.total(let total)): "complete \(total.clockText(rounding: .down))"
            case .complete(.rounds(let summary)):
                "complete \(summary.total), \(summary.countText): \(summary.rows.map(\.time).joined(separator: ", "))"
            }
        }
    }

    private let clock = ManualClock()

    private func makeEngine(_ workout: Workout) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
    }

    /// The owner taps the Watch now, and the tap takes `trip` to reach the iPhone, which gives the engine what it
    /// placed.
    private func watchTaps(
        _ command: WatchCommand, _ link: inout Link, _ engine: WorkoutEngine<ManualClock>,
        trip: Duration = .milliseconds(250)
    ) async {
        let tap = clock.now
        clock.advance(by: trip)
        for (command, placed) in link.watchTaps(command, at: tap, arrivingAt: clock.now) {
            switch command {
            case .done: await engine.done(at: placed)
            case .pause: await engine.pause(at: placed)
            case .resume: await engine.resume(at: placed)
            case .stop: await engine.stop(at: placed)
            }
        }
    }

    @Test func `Intervals shows on the Watch from Start, through a Pause, to its complete screen`() async throws {
        // Prepare 0–10, Work 1 10–30, Rest 1 30–40, Work 2 40–60.
        let workout = WorkoutType.intervals.makeWorkout(
            from: WorkoutSettings(
                prepare: .seconds(10), rounds: 2, work: .seconds(20), rest: .seconds(10), cooldown: .zero))
        var link = Link(.intervals, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        clock.advance(by: .seconds(8))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(5))
        await engine.pause(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(30))
        await engine.resume(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        for seconds in [15, 10, 20] {
            clock.advance(by: .seconds(seconds))
            link.publish(try #require(await snapshots.next()), at: clock.now)
        }
        link.tapDone()

        #expect(
            link.screens == [
                "waiting", "Prepare · pause", "Work 1 · pause", "Work 1 paused · resume", "Work 1 · pause",
                "Rest 1 · pause", "Work 2 · pause", "complete 01:00", "idle",
            ])
        #expect(link.watchEffects == [.startSession, .beginCollection(at: link.epoch), .endWithoutSaving])
    }

    @Test func `A Stop in Intervals takes the Watch straight back to idle`() async throws {
        let workout = WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch)
        var link = Link(.intervals, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        clock.advance(by: .seconds(30))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        await engine.stop(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)

        #expect(link.screens == ["waiting", "Prepare · pause", "Work 1 · pause", "idle"])
        #expect(link.watchEffects == [.startSession, .beginCollection(at: link.epoch), .endWithoutSaving])
    }

    @Test func `A Stopwatch shows on the Watch, offers Done past its set length, and ends on its complete screen`()
        async throws
    {
        // Prepare 0–10, then Work counting up to 10:00 at 610 and on until Done.
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        var link = Link(.stopwatch, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        for seconds in [8, 600] {
            clock.advance(by: .seconds(seconds))
            link.publish(try #require(await snapshots.next()), at: clock.now)
        }
        clock.advance(by: .seconds(95))
        await engine.done(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        link.tapDone()

        #expect(
            link.screens == ["waiting", "Prepare · pause", "Work · pause", "Work · done", "complete 11:45", "idle"])
        #expect(link.watchEffects == [.startSession, .beginCollection(at: link.epoch), .endWithoutSaving])
    }

    @Test func `Open Rounds shows on the Watch, Round by Round, and ends on its Rounds complete screen`() async throws {
        // No Prepare: an open Work from Start, then a 1:00 Rest after each Done.
        let workout = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)
        var link = Link(.openRounds, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        clock.advance(by: .seconds(100))
        await engine.done(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(60))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(88))
        await engine.stop(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        link.tapDone()

        #expect(
            link.screens == [
                "waiting", "Work 1 · done", "Rest 1 · doneDimmed", "Work 2 · done",
                "complete 04:10, 2 Rounds: 1:42, 1:28",
                "idle",
            ])
        #expect(link.watchEffects == [.startSession, .beginCollection(at: link.epoch), .endWithoutSaving])
    }

    // MARK: The Watch as the remote

    @Test func `Open Rounds runs from Start to Stop with only the Watch, and a late tap is refused`() async throws {
        // No Prepare: an open Work from Start, then a 1:00 Rest after each Done.
        let workout = WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch)
        var link = Link(.openRounds, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        // The capsule's Done at 100 ends Work 1 there, not when it reaches the iPhone. Rest 1 runs 100–160.
        clock.advance(by: .seconds(98))
        await watchTaps(.done, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .milliseconds(59_750))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        // The secondary page's Pause at 180 and Resume at 190.
        clock.advance(by: .seconds(20))
        await watchTaps(.pause, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .milliseconds(9_750))
        await watchTaps(.resume, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        // A Done made at 200 that takes 2.5 s to arrive is refused, and Work 2 runs on.
        clock.advance(by: .milliseconds(9_750))
        await watchTaps(.done, &link, engine, trip: .milliseconds(2_500))
        // Stop, tapped at 230 and again at 231, ends Work 2 at 231.
        clock.advance(by: .milliseconds(27_500))
        var stop = StopConfirmation()
        #expect(stop.tap(at: link.date(of: clock.now)) == .askAgain)
        clock.advance(by: .seconds(1))
        #expect(stop.tap(at: link.date(of: clock.now)) == .end)
        await watchTaps(.stop, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        link.tapDone()

        #expect(
            link.screens == [
                "waiting", "Work 1 · done", "Rest 1 · doneDimmed", "Work 2 · done", "Work 2 paused · doneDimmed",
                "Work 2 · done", "complete 03:41, 2 Rounds: 1:40, 1:01", "idle",
            ])
        let tapped = { (seconds: Double) in link.date(of: Instant(offset: .seconds(seconds))) }
        #expect(
            link.watchEffects == [
                .startSession, .beginCollection(at: link.epoch), .send(.tap(.done, at: tapped(100))),
                .send(.tap(.pause, at: tapped(180))), .send(.tap(.resume, at: tapped(190))),
                .send(.tap(.done, at: tapped(200))), .tapRefused(.done), .send(.tap(.stop, at: tapped(231))),
                .endWithoutSaving,
            ])
    }

    @Test func `A Stopwatch runs from Start to its complete screen with only the Watch's capsule`() async throws {
        // Prepare 0–10, then Work counting up to 10:00 and on until Done.
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        var link = Link(.stopwatch, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        clock.advance(by: .seconds(8))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        // Paused from 60 to 90, so the Work reaches its set length at 640.
        clock.advance(by: .seconds(50))
        await watchTaps(.pause, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .milliseconds(29_750))
        await watchTaps(.resume, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .milliseconds(549_750))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(20))
        await watchTaps(.done, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        link.tapDone()

        #expect(
            link.screens == [
                "waiting", "Prepare · pause", "Work · pause", "Work paused · resume", "Work · pause", "Work · done",
                "complete 10:30", "idle",
            ])
    }

    @Test func `A Stop from the Watch's secondary page takes a Stopwatch's Watch straight back to idle`()
        async throws
    {
        let workout = WorkoutType.stopwatch.makeWorkout(from: WorkoutType.stopwatch.firstLaunch)
        var link = Link(.stopwatch, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        clock.advance(by: .seconds(8))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(40))
        await watchTaps(.stop, &link, engine)
        link.publish(try #require(await snapshots.next()), at: clock.now)

        #expect(link.screens == ["waiting", "Prepare · pause", "Work · pause", "idle"])
    }
}
