import Foundation
import Testing

@testable import TemperCore

/// The iPhone's side of the running link: what it sends each mirrored Watch session, and when.
nonisolated struct PhoneFlowTests {
    private typealias Flow = PhoneFlow<Int>

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

    private func started(workoutsAllowed: Bool = true) -> Flow {
        var flow = Flow()
        _ = flow.handle(
            .started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: workoutsAllowed))
        return flow
    }

    @Test func `Start opens the Watch when workouts are allowed`() {
        var flow = Flow()

        let effects = flow.handle(
            .started(workoutID: workoutID, workoutType: .openRounds, start: start, workoutsAllowed: true))

        #expect(effects == [.startWatchApp(.openRounds)])
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

    @Test func `A session that started before the Start gets nothing`() {
        var flow = started()
        _ = flow.handle(.published(phase(.work, startingAt: 0)))

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(-5), at: start.addingTimeInterval(2)))

        #expect(effects == [])
    }

    @Test func `A session with no Workout running gets nothing`() {
        var flow = Flow()

        let effects = flow.handle(.instanceArrived(1, start: start, at: start))

        #expect(effects == [])
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

    @Test func `A session arriving more than 10 s after Start is late`() {
        var flow = started()

        let effects = flow.handle(
            .instanceArrived(1, start: start.addingTimeInterval(9), at: start.addingTimeInterval(10.5)))

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
}
