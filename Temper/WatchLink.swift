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
    /// The mirrored sessions the flow took, until each one ends.
    private var sessions: [ObjectIdentifier: HKWorkoutSession] = [:]
    private let effects: AsyncStream<Flow.Effect>.Continuation

    /// `workoutsAllowed` reads the iPhone's workout write status, which is also the Watch's.
    init(workoutsAllowed: @escaping () -> Bool = { HealthKitWorkouts().writeStatus == .allowed }) {
        self.workoutsAllowed = workoutsAllowed
        let (stream, effects) = AsyncStream.makeStream(of: Flow.Effect.self)
        self.effects = effects
        super.init()
        store.workoutSessionMirroringStartHandler = { [weak self] session in
            let arrival = Date.now
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

    /// Sends the Watch's state after each engine event.
    func show(_ state: WatchState) {
        handle(.published(state))
    }

    private func arrived(_ session: HKWorkoutSession, at arrival: Date) {
        let id = ObjectIdentifier(session)
        let effects = flow.handle(.instanceArrived(id, start: session.startDate ?? arrival, at: arrival))
        // A session the flow doesn't take belongs to no running Workout, so it's left alone.
        guard !effects.isEmpty else { return }
        session.delegate = self
        sessions[id] = session
        enqueue(effects)
    }

    private func ended(_ id: ObjectIdentifier) {
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
            // The completion only means the request was delivered, and Start never waits for the Watch.
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
        guard toState == .ended else { return }
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in self.ended(id) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}
}
