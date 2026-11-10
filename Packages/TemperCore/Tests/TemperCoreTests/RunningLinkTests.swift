import Foundation
import Testing

@testable import TemperCore

/// A whole Workout of each Workout Type, run by the engine on the iPhone, followed on the Watch: every snapshot goes
/// through `PhoneFlow`, and every message it sends goes into `WatchFlow`. At the end the Watch saves the iPhone's own
/// Health record, or nothing when there's none.
@Suite(.timeLimit(.minutes(1)))
nonisolated struct RunningLinkTests {
    private typealias Instant = ManualClock.Instant

    /// The two flows joined as the mirrored session joins them, with one Watch session, numbered 1.
    private struct Link {
        let workoutType: WorkoutType
        let workout: Workout
        /// The wall clock at the engine clock's zero.
        let epoch = RunningLinkTests.epoch
        let workoutID = UUID()
        /// The Health record the iPhone saved itself, or `nil` before the end or for a Workout too short to save.
        var phoneRecord: HealthRecord?

        var phone = PhoneFlow<Int, Instant>()
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
                    .started(
                        workoutID: workoutID, workoutType: workoutType, start: date(of: start), workoutsAllowed: true)
                ))
        }

        /// The Watch's session reaches the iPhone, mirrored.
        mutating func watchArrives(at now: Instant) {
            #expect(isWatchOpening)
            self.now = now
            route(phone.handle(.instanceArrived(1, start: date(of: now), at: date(of: now))))
        }

        /// The iPhone publishes the state of `snapshot`, and the Watch draws what it's sent. An ended snapshot's
        /// Health record goes first, as `WorkoutRunner` hands it to its own save.
        mutating func publish(_ snapshot: WorkoutSnapshot<Instant>, at now: Instant) {
            self.now = now
            if let record = snapshot.record {
                phoneRecord = HealthRecord(
                    record, of: workoutType, workoutID: workoutID, attempt: 1,
                    anchor: ClockAnchor(instant: Instant(offset: .zero), date: epoch))
                route(phone.handle(.recordReady(phoneRecord)))
            }
            let display = RunningDisplay(workoutType: workoutType, workout: workout, snapshot: snapshot)
            route(phone.handle(.published(display.watchState(at: now, date: date(of: now)))))
            if case .running(let phase, _) = watch.screen {
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
            now = tap
            let before = watchEffects.count
            watchHandles(.tapped(command, at: date(of: tap)))
            now = arrival
            for case .send(let message) in watchEffects[before...] {
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
                    watchHandles(.received(try! MessageToWatch(json: message.json()), at: arrival))
                case .stopActivity(1):
                    watchHandles(.sessionStopped)
                    watchHandles(.sessionEnded(at: arrival))
                    route(phone.handle(.instanceEnded(1)))
                case .apply(let command, let placed):
                    commands.append((command, placed))
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
                case .cancelAllHaptics: scheduled = []
                case .playHaptic(let cue): taps.append(WristTap(cue, at: arrival))
                case .scheduleHaptics(let cues): scheduled += cues
                case .startSession, .beginCollection, .pauseSession, .resumeSession, .endAndSave, .endWithoutSaving,
                    .send, .signalRefused, .startOutOfContactTimer, .stopOutOfContactTimer:
                    watchEffects.append(effect)
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
            case .running(let phase, _):
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
        // Paused from 15 to 45, ended at 90: the Watch saves those times, the iPhone's own.
        let record = try #require(link.phoneRecord)
        #expect(record.pauses == [HealthRecord.Pause(start: link.epoch + 15, end: link.epoch + 45)])
        #expect(record.end == link.epoch + 90)
        #expect(
            link.watchEffects == [
                .startSession, .beginCollection(at: link.epoch), .pauseSession, .resumeSession,
                .endAndSave(record.withSyncVersion(1_000_000)),
            ])
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

        // Stopped after 32 s, under the minute a Health workout needs, so neither device saves.
        #expect(link.screens == ["waiting", "Prepare · pause", "Work 1 · pause", "idle"])
        #expect(link.phoneRecord == nil)
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
        let record = try #require(link.phoneRecord)
        #expect(record.end == link.epoch + 705)
        #expect(
            link.watchEffects == [
                .startSession, .beginCollection(at: link.epoch), .endAndSave(record.withSyncVersion(1_000_000)),
            ])
        #expect(link.taps == [WristTap(.work, at: 10), WristTap(.finish, at: 610)])
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
        // One activity per Phase, with its Round, as the iPhone saves them.
        let record = try #require(link.phoneRecord)
        #expect(
            record.activities == [
                HealthRecord.Activity(phase: .work, round: 1, start: link.epoch, end: link.epoch + 102),
                HealthRecord.Activity(phase: .rest, round: 1, start: link.epoch + 102, end: link.epoch + 162),
                HealthRecord.Activity(phase: .work, round: 2, start: link.epoch + 162, end: link.epoch + 250),
            ])
        #expect(
            link.watchEffects == [
                .startSession, .beginCollection(at: link.epoch), .endAndSave(record.withSyncVersion(1_000_000)),
            ])
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
        // The Watch's own tap times, not their arrivals, are what the Watch saves.
        let record = try #require(link.phoneRecord)
        #expect(record.pauses == [HealthRecord.Pause(start: link.epoch + 180, end: link.epoch + 190)])
        #expect(record.end == link.epoch + 231)
        let tapped = { (seconds: Double) in link.date(of: Instant(offset: .seconds(seconds))) }
        #expect(
            link.watchEffects == [
                .startSession, .beginCollection(at: link.epoch), .send(.tap(.done, at: tapped(100))),
                .send(.tap(.pause, at: tapped(180))), .pauseSession, .send(.tap(.resume, at: tapped(190))),
                .resumeSession, .send(.tap(.done, at: tapped(200))), .signalRefused(.done),
                .send(.tap(.stop, at: tapped(231))), .endAndSave(record.withSyncVersion(1_000_000)),
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
