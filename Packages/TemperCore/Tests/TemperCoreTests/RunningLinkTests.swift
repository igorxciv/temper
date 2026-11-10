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
        let epoch = RunningLinkTests.epoch

        var phone = PhoneFlow<Int>()
        var watch = WatchFlow()
        /// What the Watch did with its session, leaving out haptics, which go to the wrist.
        var watchEffects: [WatchFlow.Effect] = []
        /// Each Cue's haptic the wrist played, and when it started.
        var taps: [WristTap] = []
        /// The haptics scheduled and not yet played or cancelled.
        private var scheduled: [WatchCue] = []
        /// The engine's time of the latest thing to happen.
        private var now = Instant(offset: .zero)
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
            now = start
            route(
                phone.handle(
                    .started(workoutID: UUID(), workoutType: workoutType, start: date(of: start), workoutsAllowed: true)
                ))
        }

        /// The Watch's session reaches the iPhone, mirrored.
        mutating func watchArrives(at now: Instant) {
            #expect(isWatchOpening)
            self.now = now
            route(phone.handle(.instanceArrived(1, start: date(of: now), at: date(of: now))))
        }

        /// The iPhone publishes the state of `snapshot`, and the Watch draws what it's sent.
        mutating func publish(_ snapshot: WorkoutSnapshot<Instant>, at now: Instant) {
            self.now = now
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

        private mutating func route(_ effects: [PhoneFlow<Int>.Effect]) {
            for effect in effects {
                switch effect {
                case .startWatchApp:
                    isWatchOpening = true
                    watchHandles(.launched(workoutsAllowed: true))
                case .send(let message, to: 1):
                    // Through JSON, as over the session.
                    watchHandles(.received(try! MessageToWatch(json: message.json()), at: arrival))
                case .stopActivity(1):
                    watchHandles(.sessionStopped)
                    watchHandles(.sessionEnded)
                    route(phone.handle(.instanceEnded(1)))
                case .send, .stopActivity:
                    Issue.record("An effect for a session that doesn't exist: \(effect)")
                }
            }
        }

        /// When a message sent now reaches the Watch, as over Bluetooth.
        private var arrival: Date {
            date(of: now).addingTimeInterval(0.05)
        }

        private mutating func watchHandles(_ event: WatchFlow.Event) {
            // The wrist plays what came due while nothing else happened.
            let arrival = arrival
            for cue in scheduled where cue.date <= arrival {
                taps.append(WristTap(cue.cue, at: cue.date))
            }
            scheduled.removeAll { $0.date <= arrival }
            for effect in watch.handle(event) {
                switch effect {
                case .cancelHaptics(let after): scheduled.removeAll { $0.date > after }
                case .playHaptic(let cue): taps.append(WristTap(cue, at: arrival))
                case .scheduleHaptics(let cues): scheduled += cues
                case .startSession, .beginCollection, .endWithoutSaving: watchEffects.append(effect)
                }
            }
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

    private static let epoch = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// A Cue's haptic on the wrist, timed in seconds after the engine clock's zero.
    private struct WristTap: Equatable, CustomStringConvertible {
        let cue: Cue
        let seconds: Double

        init(_ cue: Cue, at date: Date) {
            self.cue = cue
            seconds = (date.timeIntervalSince(RunningLinkTests.epoch) * 1_000).rounded() / 1_000
        }

        init(_ cue: Cue, at seconds: Double) {
            self.cue = cue
            self.seconds = seconds
        }

        var description: String { "\(cue) at \(seconds)" }
    }

    private let clock = ManualClock()

    private func makeEngine(_ workout: Workout) -> WorkoutEngine<ManualClock> {
        WorkoutEngine(workout: workout, clock: clock, audio: FakeAudioOutput(), isDipOn: false)
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

    // MARK: Cue haptics

    @Test func `0:20/0:10 Intervals taps the wrist on time at every Cue`() async throws {
        // Prepare 0–10, Work 1 10–30, Rest 1 30–40, Work 2 40–60, Rest 2 60–70, Work 3 70–90, Cooldown 90–120.
        let workout = WorkoutType.intervals.makeWorkout(
            from: WorkoutSettings(
                prepare: .seconds(10), rounds: 3, work: .seconds(20), rest: .seconds(10), cooldown: .seconds(30)))
        var link = Link(.intervals, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        for seconds in [8, 20, 10, 20, 10, 20, 30] {
            clock.advance(by: .seconds(seconds))
            link.publish(try #require(await snapshots.next()), at: clock.now)
        }

        #expect(
            link.taps == [
                WristTap(.work, at: 10), WristTap(.rest, at: 30), WristTap(.work, at: 40), WristTap(.rest, at: 60),
                WristTap(.work, at: 70), WristTap(.cooldown, at: 90), WristTap(.workoutComplete, at: 120),
            ])
    }

    /// The Watch arrives after Round 1's Work has begun, too late for its Cue.
    @Test func `An Open Rounds Rest of 0:30 taps the wrist at Done, at 10 seconds, and at the next Work`() async throws
    {
        var settings = WorkoutType.openRounds.firstLaunch
        settings[.rest] = 30
        let workout = WorkoutType.openRounds.makeWorkout(from: settings)
        var link = Link(.openRounds, workout)
        let engine = makeEngine(workout)
        var snapshots = engine.snapshots.makeAsyncIterator()

        link.started(at: try #require(await engine.start()))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(2))
        link.watchArrives(at: clock.now)
        // Done at 40 starts Rest 1, 40–70. Work 2 runs from 70 until Done at 100 starts Rest 2, 100–130.
        clock.advance(by: .seconds(38))
        await engine.done(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(30))
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(30))
        await engine.done(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        // A Stop at 110 cuts Rest 2's "10 seconds" and Work.
        clock.advance(by: .seconds(10))
        await engine.stop(at: clock.now)
        link.publish(try #require(await snapshots.next()), at: clock.now)
        clock.advance(by: .seconds(30))
        link.tapDone()

        #expect(
            link.taps == [
                WristTap(.rest, at: 40.05), WristTap(.tenSeconds, at: 60), WristTap(.work, at: 70),
                WristTap(.rest, at: 100.05),
            ])
    }
}
