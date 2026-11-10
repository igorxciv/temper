import Foundation
import Testing

@testable import TemperCore

/// The Watch's side of the running link: what it shows and does for each thing that happens to it.
nonisolated struct WatchFlowTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let workoutID = UUID()

    private var begin: MessageToWatch {
        .begin(
            workoutID: workoutID, start: start, workoutType: .intervals, inTime: true, version: MessageToWatch.version)
    }

    private var work: WatchPhase {
        WatchPhase(
            kind: .work, round: 1, start: start.addingTimeInterval(10), end: start.addingTimeInterval(50),
            pausedAt: nil, countsUp: false, line: .value("1", caption: .after("of 8"), spoken: "Round 1 of 8"),
            capsule: .pause)
    }

    /// A Watch opened for a Workout, its session started, and the iPhone's `begin` and first update received.
    private func running() -> WatchFlow {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(.received(begin))
        _ = flow.handle(.received(.update(.phase(work))))
        return flow
    }

    @Test func `Opened for a Workout with workouts allowed, the Watch starts its session and waits for the iPhone`() {
        var flow = WatchFlow()

        let effects = flow.handle(.launched(workoutsAllowed: true))

        #expect(effects == [.startSession])
        #expect(flow.screen == .waiting)
    }

    /// The iPhone opens the Watch only with workouts allowed, but the status can change while the Watch opens.
    @Test func `Opened for a Workout without workouts allowed, the Watch starts no session and stays idle`() {
        var flow = WatchFlow()

        let effects = flow.handle(.launched(workoutsAllowed: false))

        #expect(effects == [])
        #expect(flow.screen == .idle)
    }

    @Test func `The iPhone's begin starts collection at the Workout's Start, and the Watch waits on for an update`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(.received(begin))

        #expect(effects == [.beginCollection(at: start)])
        #expect(flow.screen == .waiting)
    }

    /// A reconnect sends `begin` again, to a session that has already begun collecting.
    @Test func `A repeated begin for the same Workout changes nothing`() {
        var flow = running()

        let effects = flow.handle(.received(begin))

        #expect(effects == [])
        #expect(flow.screen == .running(work))
    }

    @Test func `Each update shows the Phase it carries`() {
        var flow = running()
        let paused = WatchPhase(
            kind: .work, round: 1, start: work.start, end: work.end, pausedAt: start.addingTimeInterval(20),
            countsUp: false, line: .paused, capsule: .resume)

        let effects = flow.handle(.received(.update(.phase(paused))))

        #expect(effects == [])
        #expect(flow.screen == .running(paused))
    }

    @Test func `An update before begin is ignored`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        _ = flow.handle(.received(.update(.phase(work))))

        #expect(flow.screen == .waiting)
    }

    @Test func `An ended Workout with a complete screen shows it until Done, then goes back to idle`() {
        var flow = running()

        _ = flow.handle(.received(.update(.ended(.total(.seconds(530))))))
        #expect(flow.screen == .complete(.total(.seconds(530))))

        let effects = flow.handle(.doneTapped)
        #expect(effects == [])
        #expect(flow.screen == .idle)
    }

    @Test func `A Workout ended with no complete screen goes straight back to idle`() {
        var flow = running()

        _ = flow.handle(.received(.update(.ended(nil))))

        #expect(flow.screen == .idle)
    }

    /// The iPhone's own Health workout covers every Workout until the Watch saves.
    @Test func `The iPhone's end makes the Watch end its session without saving, and keep its screen`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(530))))))

        let effects = flow.handle(.received(.end(nil)))

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .complete(.total(.seconds(530))))
    }

    /// The iPhone sends `end`, then stops the mirrored session, which the Watch sees as its session stopping.
    @Test func `The session stopping after the iPhone's end ends nothing twice`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(nil))))
        _ = flow.handle(.received(.end(nil)))

        #expect(flow.handle(.sessionStopped) == [])
        #expect(flow.handle(.received(.end(nil))) == [])
    }

    @Test func `The session stopping with no end from the iPhone still ends it without saving`() {
        var flow = running()

        let effects = flow.handle(.sessionStopped)

        #expect(effects == [.endWithoutSaving])
    }

    @Test func `A session that ends while waiting or running takes the Watch back to idle`() {
        var waiting = WatchFlow()
        _ = waiting.handle(.launched(workoutsAllowed: true))
        var running = running()

        _ = waiting.handle(.sessionEnded)
        _ = running.handle(.sessionEnded)

        #expect(waiting.screen == .idle)
        #expect(running.screen == .idle)
    }

    @Test func `A session that ends under the complete screen leaves it for Done`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(530))))))

        _ = flow.handle(.sessionEnded)

        #expect(flow.screen == .complete(.total(.seconds(530))))
    }

    /// The iPhone's own copy then covers the Workout.
    @Test func `A begin of another version shows Update Temper and ends the session without saving`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(
            .received(
                .begin(
                    workoutID: workoutID, start: start, workoutType: .intervals, inTime: true,
                    version: MessageToWatch.version + 1)))

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .updateNeeded)
    }

    @Test func `After Update Temper, the Workout's updates and end change nothing`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(
            .received(
                .begin(
                    workoutID: workoutID, start: start, workoutType: .intervals, inTime: true,
                    version: MessageToWatch.version + 1)))

        _ = flow.handle(.received(.update(.phase(work))))
        let effects = flow.handle(.received(.end(nil))) + flow.handle(.sessionStopped) + flow.handle(.sessionEnded)

        #expect(effects == [])
        #expect(flow.screen == .updateNeeded)
    }

    // MARK: Taps

    /// No acknowledgement comes back: the update the tap causes shows it worked.
    @Test func `A tap on a running Workout goes to the iPhone dated when it was made, and changes nothing yet`() {
        var flow = running()
        let tap = start.addingTimeInterval(20)

        let effects = flow.handle(.tapped(.pause, at: tap))

        #expect(effects == [.send(.tap(.pause, at: tap))])
        #expect(flow.screen == .running(work))
    }

    @Test func `With no Workout running on the Watch, a tap sends nothing`() {
        var waiting = WatchFlow()
        _ = waiting.handle(.launched(workoutsAllowed: true))
        var complete = running()
        _ = complete.handle(.received(.update(.ended(.total(.seconds(530))))))
        var idle = WatchFlow()

        #expect(waiting.handle(.tapped(.stop, at: start)) == [])
        #expect(complete.handle(.tapped(.stop, at: start)) == [])
        #expect(idle.handle(.tapped(.stop, at: start)) == [])
    }

    @Test func `A tap the iPhone refused shows the Watch it failed`() {
        var flow = running()

        let effects = flow.handle(.received(.refused(.done)))

        #expect(effects == [.signalRefused(.done)])
        #expect(flow.screen == .running(work))
    }

    @Test func `Opened again during a session, the Watch ends the old one without saving and starts afresh`() {
        var flow = running()

        let effects = flow.handle(.launched(workoutsAllowed: true))

        #expect(effects == [.endWithoutSaving, .startSession])
        #expect(flow.screen == .waiting)
    }
}
