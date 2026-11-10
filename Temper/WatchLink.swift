import Foundation
import HealthKit
import TemperCore

/// Keeps the Watch in step with the running Workout, over the workout session the Watch starts and mirrors back.
///
/// `PhoneFlow` decides what to send and when. This adapter only calls HealthKit: it opens the Watch, keeps the
/// mirrored sessions the flow takes, and carries out the flow's effects one at a time, in order, so `end` lands
/// before the session is stopped.
///
/// One link serves the app for as long as it runs. It's made at launch, because HealthKit may launch the app in the
/// background to hand over a mirrored session.
final class WatchLink: NSObject {
    private typealias Flow = PhoneFlow<ObjectIdentifier>

    private let store = HKHealthStore()
    private let workoutsAllowed: () -> Bool
    private var flow = Flow()
    /// The mirrored sessions the flow has messages for, leftovers included, until each one ends.
    private var sessions: [ObjectIdentifier: HKWorkoutSession] = [:]
    /// Mirrored sessions that arrived before their activity started, so with no start date to match by yet, and when
    /// each arrived. Each is matched once it reports running.
    private var unstarted: [ObjectIdentifier: (session: HKWorkoutSession, arrival: Date)] = [:]
    private let effects: AsyncStream<Flow.Effect>.Continuation

    /// `workoutsAllowed` reads the iPhone's workout write status, which is also the Watch's.
    init(workoutsAllowed: @escaping () -> Bool = { HealthKitWorkouts().writeStatus == .allowed }) {
        self.workoutsAllowed = workoutsAllowed
        let (stream, effects) = AsyncStream.makeStream(of: Flow.Effect.self)
        self.effects = effects
        super.init()
        store.workoutSessionMirroringStartHandler = { [weak self] session in
            let arrival = Date.now
            // Set here rather than after the hop, so no change of state can slip by unreported.
            session.delegate = self
            Task { @MainActor in self?.arrived(session, at: arrival) }
        }
        Task { [weak self] in
            for await effect in stream {
                await self?.perform(effect)
            }
        }
    }

    /// Opens the Watch if workouts are allowed, once the engine has set the Workout's start point at `start`.
    func start(workoutID: UUID, workoutType: WorkoutType, start: Date) {
        handle(
            .started(workoutID: workoutID, workoutType: workoutType, start: start, workoutsAllowed: workoutsAllowed()))
    }

    /// Holds the Health record the iPhone saves for the Workout that just ended, or `nil` for none, until the Watch's
    /// session has ended. It comes before the ended state, which sends it to the Watch in `end`. It's kept only in
    /// memory: if the app dies first, the Watch's own fallback covers the Workout.
    func hold(_ record: HealthRecord?) {
        handle(.recordReady(record))
    }

    /// Sends the Watch's state after each engine event.
    func show(_ state: WatchState) {
        handle(.published(state))
    }

    /// The Watch mirrors its session before starting its activity, so a session can arrive with no start date. It's
    /// matched by its start date once it has one, never by its arrival, so a leftover session isn't taken for the
    /// running Workout's. One that never starts gets nothing, and the Watch ends it after its own 10 minutes.
    private func arrived(_ session: HKWorkoutSession, at arrival: Date) {
        guard let start = session.startDate else {
            unstarted[ObjectIdentifier(session)] = (session, arrival)
            return
        }
        match(session, start: start, arrival: arrival)
    }

    private func started(_ id: ObjectIdentifier, at start: Date) {
        guard let (session, arrival) = unstarted.removeValue(forKey: id) else { return }
        match(session, start: session.startDate ?? start, arrival: arrival)
    }

    private func match(_ session: HKWorkoutSession, start: Date, arrival: Date) {
        let id = ObjectIdentifier(session)
        // Kept even when it belongs to no running Workout, since the flow then tells it to end without saving.
        sessions[id] = session
        handle(.instanceArrived(id, start: start, at: arrival))
    }

    private func ended(_ id: ObjectIdentifier) {
        unstarted[id] = nil
        guard sessions.removeValue(forKey: id) != nil else { return }
        handle(.instanceEnded(id))
    }

    private func handle(_ event: Flow.Event) {
        enqueue(flow.handle(event))
    }

    private func enqueue(_ effects: [Flow.Effect]) {
        for effect in effects {
            self.effects.yield(effect)
        }
    }

    private func perform(_ effect: Flow.Effect) async {
        switch effect {
        case .startWatchApp(let workoutType):
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = HealthRecord.ActivityType(workoutType).healthKit
            configuration.locationType = .indoor
            // The completion only means the request was delivered, and Start never waits for the Watch. So the
            // window is timed from the call.
            handle(.watchAppRequested(at: .now))
            store.startWatchApp(with: configuration) { _, _ in }
        case .send(let message, let id):
            guard let session = sessions[id], let data = try? message.json() else { return }
            // A send fails once the session has ended, as it does at the end of every Workout, so a failure is no
            // fault of the link.
            try? await session.sendToRemoteWorkoutSession(data: data)
        case .stopActivity(let id):
            sessions[id]?.stopActivity(with: .now)
        }
    }
}

extension WatchLink: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        let id = ObjectIdentifier(workoutSession)
        switch toState {
        case .running: Task { @MainActor in self.started(id, at: date) }
        case .ended: Task { @MainActor in self.ended(id) }
        default: break
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}
}
