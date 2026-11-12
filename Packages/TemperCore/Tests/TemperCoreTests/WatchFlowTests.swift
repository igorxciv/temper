import Foundation
import Testing

@testable import TemperCore

/// The Watch's side of the running link: what it shows and does for each thing that happens to it.
nonisolated struct WatchFlowTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private let workoutID = UUID()
    /// When the messages arrive, unless a test says otherwise: well into the Work.
    private var now: Date { start.addingTimeInterval(30) }

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

    private var record: HealthRecord {
        HealthRecord(
            WorkoutRecord(
                start: ManualClock.Instant(offset: .zero), end: ManualClock.Instant(offset: .seconds(90)),
                pauses: [ManualClock.Instant(offset: .seconds(20))..<ManualClock.Instant(offset: .seconds(30))],
                phases: [.init(kind: .work, round: 1, start: .init(offset: .zero), end: .init(offset: .seconds(90)))]),
            filedAs: .highIntensityIntervalTraining, workoutID: workoutID, attempt: 1,
            anchor: ClockAnchor(instant: ManualClock.Instant(offset: .zero), date: start))!
    }

    private var paused: WatchPhase {
        WatchPhase(
            kind: .work, round: 1, start: work.start, end: work.end, pausedAt: start.addingTimeInterval(20),
            countsUp: false, line: .paused, capsule: .resume)
    }

    /// A Watch opened for a Workout, its session started, and the iPhone's `begin` and first update received.
    private func running() -> WatchFlow {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(.received(begin, at: now))
        _ = flow.handle(.received(.update(.phase(work)), at: now))
        return flow
    }

    @Test func `Opened for a Workout with workouts allowed, the Watch starts its session and waits for the iPhone`() {
        var flow = WatchFlow()

        let effects = flow.handle(.launched(workoutsAllowed: true))

        #expect(effects == [.startSession, .awaitFirstMessage(for: .seconds(600))])
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

        let effects = flow.handle(.received(begin, at: now))

        #expect(effects == [.beginCollection(at: start)])
        #expect(flow.screen == .waiting)
    }

    /// A reconnect sends `begin` again, to a session that has already begun collecting.
    @Test func `A repeated begin for the same Workout changes nothing`() {
        var flow = running()

        let effects = flow.handle(.received(begin, at: now))

        #expect(effects == [])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    @Test func `Each update shows the Phase it carries`() {
        var flow = running()
        let rest = WatchPhase(
            kind: .rest, round: 1, start: start.addingTimeInterval(50), end: start.addingTimeInterval(60),
            pausedAt: nil,
            countsUp: false, line: nil, capsule: .pause)

        let effects = flow.handle(.received(.update(.phase(rest)), at: start.addingTimeInterval(55)))

        #expect(effects == [])
        #expect(flow.screen == .running(rest, isConnected: true))
    }

    /// So the session's active time and energy follow the Workout's.
    @Test func `The session pauses with a paused update and resumes with the next running one, once each`() {
        var flow = running()

        let pausing = flow.handle(.received(.update(.phase(paused)), at: now))
        let stillPaused = flow.handle(.received(.update(.phase(paused)), at: now))
        let resuming = flow.handle(.received(.update(.phase(work)), at: now))

        #expect(pausing == [.pauseSession])
        #expect(stillPaused == [])
        #expect(resuming == [.resumeSession])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    @Test func `An update before begin is ignored`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        _ = flow.handle(.received(.update(.phase(work)), at: now))

        #expect(flow.screen == .waiting)
    }

    @Test func `An ended Workout with a complete screen shows it until Done, then goes back to idle`() {
        var flow = running()

        _ = flow.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))
        #expect(flow.screen == .complete(.total(.seconds(530))))

        let effects = flow.handle(.doneTapped)
        #expect(effects == [])
        #expect(flow.screen == .idle)
    }

    @Test func `A Workout ended with no complete screen goes straight back to idle`() {
        var flow = running()

        _ = flow.handle(.received(.update(.ended(nil)), at: now))

        #expect(flow.screen == .idle)
    }

    /// Health keeps the higher version in place of the iPhone's copy, which has version 1.
    @Test func `The iPhone's end with a record makes the Watch save it at version 1,000,000, and keep its screen`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))

        let effects = flow.handle(.received(.end(record), at: now))

        #expect(effects == [.endAndSave(record.withSyncVersion(1_000_000))])
        #expect(flow.screen == .complete(.total(.seconds(530))))
    }

    @Test func `The session stopping after the Watch saved ends nothing twice`() {
        var flow = running()
        _ = flow.handle(.received(.end(record), at: now))

        #expect(flow.handle(.sessionStopped) == [])
        #expect(flow.handle(.received(.end(record), at: now)) == [])
    }

    /// The iPhone's own Health workout covers a Workout under 1 minute, which it doesn't save either.
    @Test func `The iPhone's end with no record makes the Watch end its session without saving, and keep its screen`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))

        let effects = flow.handle(.received(.end(nil), at: now))

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .complete(.total(.seconds(530))))
    }

    /// The iPhone sends `end`, then stops the mirrored session, which the Watch sees as its session stopping.
    @Test func `The session stopping after the iPhone's end ends nothing twice`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(nil)), at: now))
        _ = flow.handle(.received(.end(nil), at: now))

        #expect(flow.handle(.sessionStopped) == [])
        #expect(flow.handle(.received(.end(nil), at: now)) == [])
    }

    /// The iPhone stops the session only after sending `end`, and the two can reach the Watch in either order.
    @Test func `A session tied to a Workout that stops before the iPhone's end waits for it, then saves`() {
        var flow = running()

        let stopping = flow.handle(.sessionStopped)
        let ending = flow.handle(.received(.end(record), at: now))

        #expect(stopping == [])
        #expect(ending == [.endAndSave(record.withSyncVersion(1_000_000))])
    }

    @Test func `A session stopping before the iPhone's begin ends without saving`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(.sessionStopped)

        #expect(effects == [.endWithoutSaving])
    }

    @Test func `A session that ends while waiting or running takes the Watch back to idle`() {
        var waiting = WatchFlow()
        _ = waiting.handle(.launched(workoutsAllowed: true))
        var running = running()

        _ = waiting.handle(.sessionEnded(at: now))
        _ = running.handle(.sessionEnded(at: now))

        #expect(waiting.screen == .idle)
        #expect(running.screen == .idle)
    }

    @Test func `A session that ends under the complete screen leaves it for Done`() {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))

        _ = flow.handle(.sessionEnded(at: now))

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
                    version: MessageToWatch.version + 1), at: now))

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
                    version: MessageToWatch.version + 1), at: now))

        _ = flow.handle(.received(.update(.phase(work)), at: now))
        let effects =
            flow.handle(.received(.end(nil), at: now)) + flow.handle(.sessionStopped)
            + flow.handle(.sessionEnded(at: now))

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
        #expect(flow.screen == .running(work, isConnected: true))
    }

    @Test func `With no Workout running on the Watch, a tap sends nothing`() {
        var waiting = WatchFlow()
        _ = waiting.handle(.launched(workoutsAllowed: true))
        var complete = running()
        _ = complete.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))
        var idle = WatchFlow()

        #expect(waiting.handle(.tapped(.stop, at: start)) == [])
        #expect(complete.handle(.tapped(.stop, at: start)) == [])
        #expect(idle.handle(.tapped(.stop, at: start)) == [])
    }

    @Test func `A tap the iPhone refused shows the Watch it failed`() {
        var flow = running()

        let effects = flow.handle(.received(.refused(.done), at: now))

        #expect(effects == [.signalRefused(.done)])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    // MARK: Dropout

    /// 200 s after the Start, well past the minute a Health workout needs.
    private var later: Date { start.addingTimeInterval(200) }

    /// A running Watch whose link dropped at `date`.
    private func droppedOut(at date: Date) -> WatchFlow {
        var flow = running()
        _ = flow.handle(.disconnected(at: date))
        return flow
    }

    /// The record an effect saves, or `nil` if `effects` isn't one save alone.
    private func saved(by effects: [WatchFlow.Effect]) -> HealthRecord? {
        guard effects.count == 1, case .endAndSave(let record) = effects[0] else { return nil }
        return record
    }

    /// Recording carries on: the session isn't paused or ended.
    @Test func `The link dropping starts a dropout, which the screen shows, and the out-of-contact timer`() {
        var flow = running()

        let effects = flow.handle(.disconnected(at: later))

        #expect(effects == [.startOutOfContactTimer])
        #expect(flow.screen == .running(work, isConnected: false))
    }

    @Test func `The link dropping cancels the haptics scheduled, and those under way`() {
        var flow = running()
        _ = flow.handle(.received(.update(.phase(workWithRest)), at: now))

        let effects = flow.handle(.disconnected(at: now))

        #expect(effects == [.cancelAllHaptics, .startOutOfContactTimer])
    }

    @Test func `A tap during a dropout is shown to have failed, and isn't sent`() {
        var flow = droppedOut(at: later)

        let effects = flow.handle(.tapped(.pause, at: later))

        #expect(effects == [.signalRefused(.pause)])
    }

    @Test func `The link dropping again during a dropout changes nothing`() {
        var flow = droppedOut(at: later)

        #expect(flow.handle(.disconnected(at: later.addingTimeInterval(5))) == [])
    }

    /// A session with no `begin` has nothing to save.
    @Test func `The link dropping before the iPhone's begin starts no dropout`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        #expect(flow.handle(.disconnected(at: now)) == [])
        #expect(flow.screen == .waiting)
    }

    @Test func `An update ends the dropout, stops the timer and schedules its Phase's haptics again`() {
        var flow = running()
        _ = flow.handle(.received(.update(.phase(workWithRest)), at: now))
        _ = flow.handle(.disconnected(at: now))

        let effects = flow.handle(.received(.update(.phase(workWithRest)), at: now.addingTimeInterval(5)))

        #expect(
            effects == [
                .stopOutOfContactTimer, .scheduleHaptics([WatchCue(cue: .rest, date: start.addingTimeInterval(50))]),
            ])
        #expect(flow.screen == .running(workWithRest, isConnected: true))
    }

    /// A reconnect opens with `begin`, to a session that has already begun collecting.
    @Test func `A repeated begin ends the dropout, and changes nothing else`() {
        var flow = droppedOut(at: later)

        let effects = flow.handle(.received(begin, at: later.addingTimeInterval(5)))

        #expect(effects == [.stopOutOfContactTimer])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    @Test func `A refusal ends the dropout too`() {
        var flow = droppedOut(at: later)

        let effects = flow.handle(.received(.refused(.done), at: later.addingTimeInterval(5)))

        #expect(effects == [.stopOutOfContactTimer, .signalRefused(.done)])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    /// The Stop happened during the dropout, and the iPhone resends `end` to the session that reconnects.
    @Test func `The iPhone's end after a dropout saves its record, not what the Watch heard`() {
        var flow = droppedOut(at: later)

        let effects = flow.handle(.received(.end(record), at: later.addingTimeInterval(5)))

        #expect(effects == [.stopOutOfContactTimer, .endAndSave(record.withSyncVersion(1_000_000))])
    }

    // MARK: The fallback save

    /// Work 1 was heard from 10 s to 50 s, and the link dropped 200 s after the Start.
    @Test func `After 10 minutes out of contact, the Watch saves what it heard, ending at the last contact`() throws {
        var flow = droppedOut(at: later)

        let record = try #require(saved(by: flow.handle(.outOfContactTimerFired)))

        #expect(record.workoutID == workoutID)
        #expect(record.syncVersion == 1_000_000)
        #expect(record.activityType == .highIntensityIntervalTraining)
        #expect(record.start == start)
        #expect(record.end == later)
        #expect(
            record.activities == [
                HealthRecord.Activity(
                    phase: .work, round: 1, start: start.addingTimeInterval(10), end: start.addingTimeInterval(50))
            ])
        #expect(flow.screen == .idle)
    }

    @Test func `After 10 minutes out of contact under 1 minute into the Workout, the Watch ends without saving`() {
        var flow = droppedOut(at: start.addingTimeInterval(40))

        let effects = flow.handle(.outOfContactTimerFired)

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .idle)
    }

    @Test func `Once the Watch has saved alone, nothing ends twice`() {
        var flow = droppedOut(at: later)
        _ = flow.handle(.outOfContactTimerFired)

        let effects =
            flow.handle(.outOfContactTimerFired) + flow.handle(.sessionStopped)
            + flow.handle(.sessionEnded(at: later.addingTimeInterval(600)))

        #expect(effects == [])
    }

    @Test func `A timer that fires after the dropout ended does nothing`() {
        var flow = droppedOut(at: later)
        _ = flow.handle(.received(.update(.phase(work)), at: later.addingTimeInterval(5)))

        #expect(flow.handle(.outOfContactTimerFired) == [])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    /// The ended state arrived 90 s after the Start, and the link dropped before `end` could follow.
    @Test func `What the Watch saves alone ends no later than the Workout's end, if it heard it`() throws {
        var flow = running()
        _ = flow.handle(.received(.update(.ended(.total(.seconds(90)))), at: start.addingTimeInterval(90)))
        _ = flow.handle(.disconnected(at: later))

        let record = try #require(saved(by: flow.handle(.outOfContactTimerFired)))

        #expect(record.end == start.addingTimeInterval(90))
        #expect(flow.screen == .complete(.total(.seconds(90))))
    }

    /// The system ends the Watch's session when another workout app starts one.
    @Test func `Taken over by another workout app, the Watch saves what it heard, ending at the takeover`() throws {
        var flow = running()

        let record = try #require(saved(by: flow.handle(.sessionEnded(at: later))))

        #expect(record.syncVersion == 1_000_000)
        #expect(record.end == later)
        #expect(flow.screen == .idle)
    }

    @Test func `Taken over under 1 minute into the Workout, the Watch discards what it collected`() {
        var flow = running()

        let effects = flow.handle(.sessionEnded(at: start.addingTimeInterval(40)))

        #expect(effects == [.endWithoutSaving])
    }

    @Test func `Taken over during a dropout, the Watch stops the timer and saves up to the takeover`() throws {
        var flow = droppedOut(at: start.addingTimeInterval(100))

        let effects = flow.handle(.sessionEnded(at: later))

        #expect(effects.first == .stopOutOfContactTimer)
        #expect(saved(by: Array(effects.dropFirst()))?.end == later)
    }

    // MARK: Recovery

    /// HealthKit hands back the session after a Watch app crash. The Watch persisted nothing, so it waits for the
    /// iPhone, which sends the session's new mirrored instance `begin` and the latest update.
    @Test func `Recovered after a crash, the Watch waits for the iPhone and picks up where it is`() {
        var flow = WatchFlow()

        let recovering = flow.handle(.recovered(isPaused: false))
        #expect(recovering == [.awaitFirstMessage(for: .seconds(600))])
        #expect(flow.screen == .waiting)

        _ = flow.handle(.received(begin, at: later))
        let effects = flow.handle(.received(.update(.phase(work)), at: later))
        #expect(effects == [])
        #expect(flow.screen == .running(work, isConnected: true))
    }

    @Test func `A session recovered paused resumes with the first running update`() {
        var flow = WatchFlow()
        _ = flow.handle(.recovered(isPaused: true))
        _ = flow.handle(.received(begin, at: later))

        #expect(flow.handle(.received(.update(.phase(paused)), at: later)) == [])
        #expect(flow.handle(.received(.update(.phase(work)), at: later)) == [.resumeSession])
    }

    @Test func `Opened again during a session, the Watch ends the old one without saving and starts afresh`() {
        var flow = running()

        let effects = flow.handle(.launched(workoutsAllowed: true))

        #expect(effects == [.endWithoutSaving, .startSession, .awaitFirstMessage(for: .seconds(600))])
        #expect(flow.screen == .waiting)
    }

    // MARK: A late Watch

    private var lateBegin: MessageToWatch {
        .begin(
            workoutID: workoutID, start: start, workoutType: .intervals, inTime: false,
            version: MessageToWatch.version)
    }

    /// A Watch whose session reached the iPhone after the 10 s window, with the iPhone's `begin` received.
    private func late() -> WatchFlow {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(.received(lateBegin, at: now))
        return flow
    }

    /// It records all the same, from the Workout's Start.
    @Test func `A late begin starts collection at the Workout's Start and shows Running on iPhone`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(.received(lateBegin, at: now))

        #expect(effects == [.beginCollection(at: start)])
        #expect(flow.screen == .runningOnIPhone)
    }

    @Test func `A late Watch keeps Running on iPhone through each Phase, and taps no Cue on the wrist`() {
        var flow = late()
        let doneAt = start.addingTimeInterval(42)
        let rest = WatchPhase(
            kind: .rest, round: 1, start: doneAt, end: doneAt.addingTimeInterval(10), pausedAt: nil, countsUp: false,
            line: nil, capsule: .pause, cues: [WatchCue(cue: .work, date: doneAt.addingTimeInterval(10))])

        let scheduling = flow.handle(.received(.update(.phase(workWithRest)), at: now))
        let playing = flow.handle(.received(.update(.phase(rest)), at: doneAt.addingTimeInterval(0.05)))

        #expect(scheduling == [])
        #expect(playing == [])
        #expect(flow.screen == .runningOnIPhone)
    }

    /// So its copy's active time and energy follow the Workout's, as an in-time Watch's do.
    @Test func `A late Watch's session pauses and resumes with the updates`() {
        var flow = late()
        _ = flow.handle(.received(.update(.phase(work)), at: now))

        let pausing = flow.handle(.received(.update(.phase(paused)), at: now))
        let resuming = flow.handle(.received(.update(.phase(work)), at: now))

        #expect(pausing == [.pauseSession])
        #expect(resuming == [.resumeSession])
        #expect(flow.screen == .runningOnIPhone)
    }

    @Test func `A late Watch saves the iPhone's record at version 1,000,000`() {
        var flow = late()
        _ = flow.handle(.received(.update(.phase(work)), at: now))
        _ = flow.handle(.received(.update(.ended(nil)), at: now))

        let effects = flow.handle(.received(.end(record), at: now))

        #expect(effects == [.endAndSave(record.withSyncVersion(1_000_000))])
        #expect(flow.screen == .idle)
    }

    @Test func `A late Watch shows the complete screen once the Workout has ended`() {
        var flow = late()

        _ = flow.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))

        #expect(flow.screen == .complete(.total(.seconds(530))))
    }

    /// A reconnect sends `begin` again, and the iPhone fixes `inTime` at the first arrival.
    @Test func `A repeated begin leaves a late Watch on Running on iPhone`() {
        var flow = late()
        _ = flow.handle(.received(.update(.phase(work)), at: now))

        let effects = flow.handle(.received(lateBegin, at: now))

        #expect(effects == [])
        #expect(flow.screen == .runningOnIPhone)
    }

    /// It has no controls, so nothing can reach the iPhone from it.
    @Test func `A late Watch sends the iPhone no tap`() {
        var flow = late()
        _ = flow.handle(.received(.update(.phase(work)), at: now))

        #expect(flow.handle(.tapped(.pause, at: now)) == [])
    }

    @Test func `A late Watch whose session ends goes back to idle`() {
        var flow = late()

        _ = flow.handle(.sessionEnded(at: now))

        #expect(flow.screen == .idle)
    }

    /// The next Workout's Watch may be in time.
    @Test func `Opened for a new Workout after a late one, the Watch shows its Phases again`() {
        var flow = late()
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(.received(begin, at: now))

        _ = flow.handle(.received(.update(.phase(work)), at: now))

        #expect(flow.screen == .running(work, isConnected: true))
    }

    // MARK: Leftover sessions

    /// The iPhone found no running Workout the session belongs to.
    @Test func `Told to discard while waiting, the Watch ends its session without saving and goes back to idle`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(.received(.discard, at: now))

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .idle)
    }

    /// A session that reconnects after its Workout has given way to the next one.
    @Test func `Told to discard while following a Workout, the Watch ends its session without saving`() {
        var flow = running()

        let effects = flow.handle(.received(.discard, at: now))

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .idle)
        #expect(flow.handle(.sessionStopped) == [])
    }

    // MARK: The wait for the iPhone

    /// It never began collection, so it has nothing to save.
    @Test func `With no first message in time, the Watch ends its session without saving and goes back to idle`() {
        var flow = WatchFlow()
        _ = flow.handle(.launched(workoutsAllowed: true))

        let effects = flow.handle(.firstMessageTimedOut)

        #expect(effects == [.endWithoutSaving])
        #expect(flow.screen == .idle)
    }

    /// After `begin` an in-time Watch still shows "Connecting to iPhone", until its first update.
    @Test func `Once begin has arrived, the wait running out changes nothing`() {
        var waiting = WatchFlow()
        _ = waiting.handle(.launched(workoutsAllowed: true))
        _ = waiting.handle(.received(begin, at: now))
        var running = running()
        var late = late()

        #expect(waiting.handle(.firstMessageTimedOut) == [])
        #expect(running.handle(.firstMessageTimedOut) == [])
        #expect(late.handle(.firstMessageTimedOut) == [])
        #expect(waiting.screen == .waiting)
        #expect(running.screen == .running(work, isConnected: true))
        #expect(late.screen == .runningOnIPhone)
    }

    @Test func `With its session already ended, the wait running out changes nothing`() {
        var discarded = WatchFlow()
        _ = discarded.handle(.launched(workoutsAllowed: true))
        _ = discarded.handle(.received(.discard, at: now))
        var complete = running()
        _ = complete.handle(.received(.update(.ended(.total(.seconds(530)))), at: now))
        _ = complete.handle(.received(.end(record), at: now))

        #expect(discarded.handle(.firstMessageTimedOut) == [])
        #expect(complete.handle(.firstMessageTimedOut) == [])
        #expect(complete.screen == .complete(.total(.seconds(530))))
    }

    // MARK: Cue haptics

    /// Work 1 from 10 s to 50 s, with Rest due at its end.
    private var workWithRest: WatchPhase {
        WatchPhase(
            kind: .work, round: 1, start: work.start, end: work.end, pausedAt: nil, countsUp: false, line: work.line,
            capsule: .pause, cues: [WatchCue(cue: .rest, date: start.addingTimeInterval(50))])
    }

    @Test func `An update schedules the haptics of its Phase's Cues`() {
        var flow = running()

        let effects = flow.handle(.received(.update(.phase(workWithRest)), at: now))

        #expect(effects == [.scheduleHaptics([WatchCue(cue: .rest, date: start.addingTimeInterval(50))])])
    }

    @Test func `A newer update cancels the haptics scheduled for after it arrives`() {
        var flow = running()
        _ = flow.handle(.received(.update(.phase(workWithRest)), at: now))

        let effects = flow.handle(.received(.update(.ended(nil)), at: now))

        #expect(effects == [.cancelHaptics(after: now)])
    }

    @Test func `A Phase reached at Done plays its Cue as its update arrives`() {
        var flow = running()
        let doneAt = start.addingTimeInterval(42)
        let rest = WatchPhase(
            kind: .rest, round: 1, start: doneAt, end: doneAt.addingTimeInterval(10), pausedAt: nil, countsUp: false,
            line: nil, capsule: .pause)

        let effects = flow.handle(.received(.update(.phase(rest)), at: doneAt.addingTimeInterval(0.05)))

        #expect(effects == [.playHaptic(.rest)])
    }

    @Test func `The session ending cancels every haptic still scheduled`() {
        var flow = running()
        _ = flow.handle(.received(.update(.phase(workWithRest)), at: now))

        let effects = flow.handle(.received(.end(nil), at: now))

        #expect(effects == [.cancelAllHaptics, .endWithoutSaving])
    }

    /// A new Workout's first Phase can share its kind and Round with the last Workout's last.
    @Test func `Opened for a new Workout, the Watch forgets the last one's Phase`() {
        var flow = running()
        let work = WatchPhase(
            kind: .work, round: 1, start: now, end: nil, pausedAt: nil, countsUp: true, line: nil, capsule: .done)
        _ = flow.handle(.launched(workoutsAllowed: true))
        _ = flow.handle(.received(begin, at: now))

        let effects = flow.handle(.received(.update(.phase(work)), at: now.addingTimeInterval(0.05)))

        #expect(effects == [.playHaptic(.work)])
    }

    /// With the wrist down, a Watch app plays haptics only while its workout session runs.
    @Test func `With its session ended, the Watch plays no haptics`() {
        var flow = running()
        _ = flow.handle(.sessionEnded(at: now))

        let effects = flow.handle(.received(.update(.phase(workWithRest)), at: now))

        #expect(effects == [])
    }
}
