import Foundation
import Testing

@testable import TemperCore

/// The iPhone's side of the running link: what it sends each mirrored Watch session, and when.
nonisolated struct PhoneFlowTests {
    private typealias Flow = PhoneFlow<Int, ManualClock.Instant>
    private typealias Instant = ManualClock.Instant

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let workoutID = UUID()

    private func begin(inTime: Bool = true) -> MessageToWatch {
        .begin(
            workoutID: workoutID, start: start, workoutType: .openRounds, inTime: inTime,
            version: MessageToWatch.version)
    }

    private func phase(_ kind: Phase.Kind, startingAt seconds: Double) -> WatchState {
        .phase(
            WatchPhase(
                kind: kind, round: 1, start: start.addingTimeInterval(seconds), end: nil, pausedAt: nil,
                countsUp: true, line: .value("1", caption: .before("Round"), spoken: "Round 1"), capsule: .done))
    }

    private var record: HealthRecord {
        HealthRecord(
            WorkoutRecord(
                start: ManualClock.Instant(offset: .zero), end: ManualClock.Instant(offset: .seconds(90)), pauses: [],
                phases: [.init(kind: .work, round: 1, start: .init(offset: .zero), end: .init(offset: .seconds(90)))]),
            of: .openRounds, workoutID: workoutID, attempt: 1,
            anchor: ClockAnchor(instant: ManualClock.Instant(offset: .zero), date: start))!
    }

    /// A Workout started, and the Watch asked to open `seconds` after the engine set the start point.
    private func started(requestingAfter seconds: Double = 0) -> Flow {
        var flow = Flow()
        _ = flow.handle(.started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: true))
        _ = flow.handle(.watchAppRequested(at: start.addingTimeInterval(seconds)))
        return flow
    }

    @Test func `Start opens the Watch when workouts are allowed`() {
        var flow = Flow()

        let effects = flow.handle(
            .started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: true))

        #expect(effects == [.startWatchApp(.openRounds)])
    }

    /// A session that turns up without the iPhone having asked for one still records, but had no window to be in.
    @Test func `A session arriving when the iPhone never asked the Watch to open is late`() {
        var flow = Flow()
        _ = flow.handle(.started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: false))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(1), at: start.addingTimeInterval(2)))

        #expect(effects == [.send(begin(inTime: false), to: 1)])
    }

    @Test func `Without workout permission, Start doesn't open the Watch`() {
        var flow = Flow()

        let effects = flow.handle(
            .started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: false))

        #expect(effects == [])
    }

    @Test func `A session started at or after the Start gets begin, then the latest update`() {
        var flow = started()
        _ = flow.handle(.published(phase(.work, startingAt: 0)))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(1.8), at: start.addingTimeInterval(2)))

        #expect(effects == [.send(begin(), to: 1), .send(.update(phase(.work, startingAt: 0)), to: 1)])
    }

    /// A leftover from an earlier Workout, which the iPhone's own copy covers.
    @Test func `A session that started before the Start is told to end without saving`() {
        var flow = started()
        _ = flow.handle(.published(phase(.work, startingAt: 0)))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(-0.001), at: start.addingTimeInterval(2)))

        #expect(effects == [.send(.discard, to: 1)])
    }

    @Test func `A session arriving with no Workout running is told to end without saving`() {
        var flow = Flow()

        let effects = flow.handle(.instanceArrived(1, start: start, at: start))

        #expect(effects == [.send(.discard, to: 1)])
    }

    /// `startWatchApp` carries no ID, so only its start date tells the first Workout's session from the second's.
    @Test func `The first Workout's session turning up during the second is told to end, and the second's is taken`() {
        var flow = started()
        _ = flow.handle(.published(.ended(nil)))
        let next = start.addingTimeInterval(120)
        let nextID = UUID()
        _ = flow.handle(.started(workoutID: nextID, workoutType: .openRounds, start: next, workoutsAllowed: true))
        _ = flow.handle(.watchAppRequested(at: next))

        let leftover = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(40), at: next.addingTimeInterval(3)))
        let taken = flow.handle(
            .instanceArrived(2, start: next.addingTimeInterval(2), at: next.addingTimeInterval(4)))
        let update = flow.handle(.published(phase(.work, startingAt: 120)))

        #expect(leftover == [.send(.discard, to: 1)])
        #expect(
            taken == [
                .send(
                    .begin(
                        workoutID: nextID, start: next, workoutType: .openRounds, inTime: true,
                        version: MessageToWatch.version),
                    to: 2)
            ])
        #expect(update == [.send(.update(phase(.work, startingAt: 120)), to: 2)])
    }

    /// The running Workout's session keeps the link while a leftover is turned away.
    @Test func `A leftover arriving after the Workout's session doesn't take its updates`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceArrived(2, start: start.addingTimeInterval(-60), at: start.addingTimeInterval(3)))

        let effects = flow.handle(.published(phase(.rest, startingAt: 90)))

        #expect(effects == [.send(.update(phase(.rest, startingAt: 90)), to: 1)])
    }

    @Test func `A session arriving before the first update gets begin alone`() {
        var flow = started()

        let effects = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))

        #expect(effects == [.send(begin(), to: 1)])
    }

    @Test func `Each state published goes to the Workout's session as an update`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))

        let effects = flow.handle(.published(phase(.rest, startingAt: 90)))

        #expect(effects == [.send(.update(phase(.rest, startingAt: 90)), to: 1)])
    }

    @Test func `With no session, a state published sends nothing`() {
        var flow = started()

        #expect(flow.handle(.published(phase(.work, startingAt: 0))) == [])
    }

    @Test func `At the end the iPhone sends the record it saves itself, then stops the Watch's session`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))

        let effects = flow.handle(.recordReady(record)) + flow.handle(.published(.ended(nil)))

        #expect(effects == [.send(.update(.ended(nil)), to: 1), .send(.end(record), to: 1), .stopActivity(1)])
    }

    /// A Workout under 1 minute has no record, so the Watch ends without saving too.
    @Test func `With no record, the iPhone's end carries none`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))

        let effects = flow.handle(.recordReady(nil)) + flow.handle(.published(.ended(nil)))

        #expect(effects == [.send(.update(.ended(nil)), to: 1), .send(.end(nil), to: 1), .stopActivity(1)])
    }

    /// A Stop during a dropout reaches the Watch when it reconnects.
    @Test func `A session arriving after the end gets the record`() {
        var flow = started()
        _ = flow.handle(.recordReady(record))
        _ = flow.handle(.published(.ended(nil)))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(3), at: start.addingTimeInterval(400)))

        #expect(
            effects == [
                .send(begin(inTime: false), to: 1), .send(.update(.ended(nil)), to: 1), .send(.end(record), to: 1),
                .stopActivity(1),
            ])
    }

    /// A Watch that wakes only after a short Workout is over collected nothing during it.
    @Test func `A session that started at or after the Workout's end is told to end without saving`() {
        var flow = started()
        _ = flow.handle(.recordReady(record))
        _ = flow.handle(.published(.ended(.total(.seconds(90)))))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(90), at: start.addingTimeInterval(91)))

        #expect(effects == [.send(.discard, to: 1)])
    }

    /// On the devices a session reaches the iPhone already running, and HealthKit gives its mirrored copy no start
    /// date. The Watch ends any older session before it starts one, so this is the Workout's.
    @Test func `A session already running on arrival, with no start date, gets begin, then the latest update`() {
        var flow = started()
        _ = flow.handle(.published(phase(.work, startingAt: 0)))

        let effects = flow.handle(.instanceArrived(1, start: nil, at: start.addingTimeInterval(2)))

        #expect(effects == [.send(begin(), to: 1), .send(.update(phase(.work, startingAt: 0)), to: 1)])
    }

    @Test func `A session with no start date arriving with no Workout running is told to end without saving`() {
        var flow = Flow()

        let effects = flow.handle(.instanceArrived(1, start: nil, at: start.addingTimeInterval(1)))

        #expect(effects == [.send(.discard, to: 1)])
    }

    /// It may have started only after the end, having collected nothing, and the iPhone can't tell.
    @Test func `The Workout's first session, with no start date, arriving after its end is told to end without saving`()
    {
        var flow = started()
        _ = flow.handle(.recordReady(record))
        _ = flow.handle(.published(.ended(.total(.seconds(90)))))

        let effects = flow.handle(.instanceArrived(1, start: nil, at: start.addingTimeInterval(91)))

        #expect(effects == [.send(.discard, to: 1)])
    }

    /// The Watch's session ran through the Workout, so the reconnect is the same session and gets the record.
    @Test func `A reconnect with no start date after a Stop during the dropout gets end with the record`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: nil, at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceDisconnected(1))
        _ = flow.handle(.recordReady(record))
        _ = flow.handle(.published(.ended(nil)))

        let reconnecting = flow.handle(.instanceArrived(2, start: nil, at: start.addingTimeInterval(200)))

        #expect(
            reconnecting == [
                .send(begin(), to: 2), .send(.update(.ended(nil)), to: 2), .send(.end(record), to: 2),
                .stopActivity(2),
            ])
    }

    /// The record is held only in memory, until the session it went to has ended.
    @Test func `Once the session that got the record ends, the record is let go`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.recordReady(record))
        _ = flow.handle(.published(.ended(nil)))

        _ = flow.handle(.instanceEnded(1))
        let effects = flow.handle(
            .instanceArrived(2, start: start.addingTimeInterval(3), at: start.addingTimeInterval(400)))

        #expect(effects.contains(.send(.end(nil), to: 2)))
    }

    @Test func `A session arriving after the end catches up to the end, and is stopped`() {
        var flow = started()
        _ = flow.handle(.published(.ended(.total(.seconds(90)))))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(3), at: start.addingTimeInterval(4)))

        #expect(
            effects == [
                .send(begin(), to: 1), .send(.update(.ended(.total(.seconds(90)))), to: 1), .send(.end(nil), to: 1),
                .stopActivity(1),
            ])
    }

    @Test func `A session arriving 10 s after the request to open the Watch is in time`() {
        var flow = started(requestingAfter: 1)

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(9), at: start.addingTimeInterval(11)))

        #expect(effects == [.send(begin(inTime: true), to: 1)])
    }

    @Test func `A session arriving just past 10 s after the request to open the Watch is late`() {
        var flow = started(requestingAfter: 1)

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(9), at: start.addingTimeInterval(11.001)))

        #expect(effects == [.send(begin(inTime: false), to: 1)])
    }

    /// A reconnect hands the iPhone a new instance, which mustn't turn an in-time Watch late.
    @Test func `Whether the Watch was in time is fixed at its first arrival`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start.addingTimeInterval(1), at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceEnded(1))

        let effects = flow.handle(
            .instanceArrived(2, start: start.addingTimeInterval(1), at: start.addingTimeInterval(60)))

        #expect(effects == [.send(begin(inTime: true), to: 2)])
    }

    @Test func `A newer session takes the updates from the one before`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceArrived(2, start: start, at: start.addingTimeInterval(30)))

        let effects = flow.handle(.published(phase(.rest, startingAt: 90)))

        #expect(effects == [.send(.update(phase(.rest, startingAt: 90)), to: 2)])
    }

    @Test func `A session that has ended gets nothing more`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))

        _ = flow.handle(.instanceEnded(1))

        #expect(flow.handle(.published(phase(.rest, startingAt: 90))) == [])
        #expect(flow.handle(.published(.ended(nil))) == [])
    }

    @Test func `A new Start forgets the last Workout's sessions and its end`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.published(.ended(nil)))
        let next = start.addingTimeInterval(600)
        let nextID = UUID()

        _ = flow.handle(.started(workoutID: nextID, workoutType: .intervals, start: next, workoutsAllowed: true))
        _ = flow.handle(.watchAppRequested(at: next))
        let effects =
            flow.handle(.published(phase(.prepare, startingAt: 600)))
            + flow.handle(.instanceArrived(2, start: next.addingTimeInterval(1), at: next.addingTimeInterval(2)))

        #expect(
            effects == [
                .send(
                    .begin(
                        workoutID: nextID, start: next, workoutType: .intervals, inTime: true,
                        version: MessageToWatch.version),
                    to: 2),
                .send(.update(phase(.prepare, startingAt: 600)), to: 2),
            ])
    }

    // MARK: Reconnecting

    /// The iPhone shows nothing during a dropout. The Watch's session reconnects by itself, as a new instance.
    @Test func `A reconnect before Stop gets begin, still in time, then the latest update, and the updates after`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.published(phase(.work, startingAt: 0)))

        let dropping = flow.handle(.instanceDisconnected(1)) + flow.handle(.published(phase(.rest, startingAt: 90)))
        let reconnecting = flow.handle(.instanceArrived(2, start: start, at: start.addingTimeInterval(200)))
        let following = flow.handle(.published(phase(.work, startingAt: 150)))

        #expect(dropping == [])
        #expect(reconnecting == [.send(begin(), to: 2), .send(.update(phase(.rest, startingAt: 90)), to: 2)])
        #expect(following == [.send(.update(phase(.work, startingAt: 150)), to: 2)])
    }

    /// A disconnected instance is no longer valid, and may report its own end while the Watch's session runs on. The
    /// record must outlast it, or the Watch that reconnects would be told there's none.
    @Test func `A reconnect after a Stop during the dropout gets begin, the ended state and end with the record`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceDisconnected(1))

        let stopping =
            flow.handle(.recordReady(record)) + flow.handle(.published(.ended(nil))) + flow.handle(.instanceEnded(1))
        let reconnecting = flow.handle(.instanceArrived(2, start: start, at: start.addingTimeInterval(200)))

        #expect(stopping == [])
        #expect(
            reconnecting == [
                .send(begin(), to: 2), .send(.update(.ended(nil)), to: 2), .send(.end(record), to: 2),
                .stopActivity(2),
            ])
    }

    @Test func `A tap through a disconnected session goes nowhere`() {
        var flow = connected()
        _ = flow.handle(.instanceDisconnected(1))

        let effects = flow.handle(
            .received(.tap(.done, at: start.addingTimeInterval(99.5)), from: 1, arrival: anchor(100)))

        #expect(effects == [])
    }

    /// An instance the newer one replaced.
    @Test func `An older session disconnecting leaves the Workout's session in place`() {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        _ = flow.handle(.instanceArrived(2, start: start, at: start.addingTimeInterval(30)))

        _ = flow.handle(.instanceDisconnected(1))

        #expect(
            flow.handle(.published(phase(.rest, startingAt: 90)))
                == [.send(.update(phase(.rest, startingAt: 90)), to: 2)])
    }

    // MARK: Taps from the Watch

    /// The engine clock read `seconds` as `date` on the wall clock, which is the Start plus `seconds`.
    private func anchor(_ seconds: Double) -> ClockAnchor<Instant> {
        ClockAnchor(instant: Instant(offset: .seconds(seconds)), date: start.addingTimeInterval(seconds))
    }

    private func connected() -> Flow {
        var flow = started()
        _ = flow.handle(.instanceArrived(1, start: start, at: start.addingTimeInterval(2)))
        return flow
    }

    @Test func `A tap in time goes to the engine, placed as far back as it was old on arrival`() {
        var flow = connected()

        let effects = flow.handle(
            .received(.tap(.done, at: start.addingTimeInterval(99.5)), from: 1, arrival: anchor(100)))

        #expect(effects == [.apply(.done, at: Instant(offset: .milliseconds(99_500)))])
    }

    @Test func `A tap more than 2 s old on arrival is refused back to the Watch, and the engine never gets it`() {
        var flow = connected()

        let effects = flow.handle(
            .received(.tap(.pause, at: start.addingTimeInterval(97.75)), from: 1, arrival: anchor(100)))

        #expect(effects == [.send(.refused(.pause), to: 1)])
    }

    /// The Live Activity's press is applied on arrival, so a Watch tap made just before it reaches the engine after.
    @Test func `A Watch tap placed before a Live Activity press the engine already applied lands just after it`()
        async throws
    {
        // Prepare 0–10, then Work.
        let clock = ManualClock()
        let engine = WorkoutEngine(
            workout: WorkoutType.intervals.makeWorkout(from: WorkoutType.intervals.firstLaunch), clock: clock,
            audio: FakeAudioOutput(), isDipOn: false)
        var snapshots = engine.snapshots.makeAsyncIterator()
        var flow = connected()
        await engine.start()
        _ = await snapshots.next()
        clock.advance(by: .seconds(4))
        await engine.pause(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .seconds(10))
        await engine.resume(at: clock.now)
        _ = await snapshots.next()
        clock.advance(by: .milliseconds(250))

        // The Watch's Pause was made at 13.5, before the Live Activity's Resume at 14, and arrives at 14.25.
        let effects = flow.handle(
            .received(.tap(.pause, at: start.addingTimeInterval(13.5)), from: 1, arrival: anchor(14.25)))
        let placed = Instant(offset: .milliseconds(13_500))
        #expect(effects == [.apply(.pause, at: placed)])
        await engine.pause(at: placed)

        // Held at the Resume, with the Prepare's 6 s left, not the 6.5 s it had at the Watch's tap.
        let paused = try #require(await snapshots.next())
        guard case .paused(let phase, let timeLeft) = paused.progress else {
            Issue.record("Not Paused: \(paused.progress)")
            return
        }
        #expect(phase.kind == .prepare)
        #expect(timeLeft == .seconds(6))
    }

    @Test func `A tap through a session that isn't the Workout's goes nowhere`() {
        var flow = connected()
        _ = flow.handle(.instanceEnded(1))

        let effects = flow.handle(
            .received(.tap(.done, at: start.addingTimeInterval(99.5)), from: 1, arrival: anchor(100)))

        #expect(effects == [])
    }

    @Test func `A tap after the Workout has ended goes nowhere`() {
        var flow = connected()
        _ = flow.handle(.published(.ended(.total(.seconds(90)))))

        let effects = flow.handle(
            .received(.tap(.stop, at: start.addingTimeInterval(99.5)), from: 1, arrival: anchor(100)))

        #expect(effects == [])
    }
}
