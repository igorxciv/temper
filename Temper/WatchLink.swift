import Foundation
import HealthKit
import TemperCore

/// Keeps the Watch in step with the running Workout, over the workout session the Watch starts and mirrors back.
///
/// `PhoneFlow` decides what to send and when. This adapter only calls HealthKit: it opens the Watch, keeps the
/// mirrored sessions the flow takes, and carries out the flow's effects one at a time, in order, so `end` lands
/// before the session is stopped. A tap from the Watch skips that queue: it goes to `tapped` as soon as it's placed,
/// so the Rest it begins isn't held up behind a send.
///
/// One link serves the app for as long as it runs. It's made at launch, because HealthKit may launch the app in the
/// background to hand over a mirrored session.
final class WatchLink: NSObject {
    private typealias Flow = PhoneFlow<ObjectIdentifier, ContinuousClock.Instant>

    private let store = HKHealthStore()
    private let workoutsAllowed: () -> Bool
    private var flow = Flow()
    /// The mirrored sessions the flow took, until each one ends.
    private var sessions: [ObjectIdentifier: HKWorkoutSession] = [:]
    /// Mirrored sessions that arrived before their activity started, so with no start date to match by yet, and when
    /// each arrived. Each is matched once it reports running.
    private var unstarted: [ObjectIdentifier: (session: HKWorkoutSession, arrival: Date)] = [:]
    private let effects: AsyncStream<Flow.Effect>.Continuation

    /// Gives the engine a tap from the Watch, at the instant the flow placed it on the engine clock.
    var tapped: (WatchCommand, ContinuousClock.Instant) -> Void = { _, _ in }

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

    /// Sends the Watch's state after each engine event.
    func show(_ state: WatchState) {
        handle(.published(state))
    }

    /// The Watch mirrors its session before starting its activity, so a session can arrive with no start date. It's
    /// matched by its start date once it has one, never by its arrival, so a leftover session isn't taken for the
    /// running Workout's.
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
        let effects = flow.handle(.instanceArrived(id, start: start, at: arrival))
        // A session the flow doesn't take belongs to no running Workout, so it's left alone.
        guard !effects.isEmpty else { return }
        sessions[id] = session
        enqueue(effects)
    }

    private func ended(_ id: ObjectIdentifier) {
        unstarted[id] = nil
        guard sessions.removeValue(forKey: id) != nil else { return }
        handle(.instanceEnded(id))
    }

    private func received(
        _ messages: [MessageFromWatch], from id: ObjectIdentifier, arrival: ClockAnchor<ContinuousClock.Instant>
    ) {
        for message in messages {
            handle(.received(message, from: id, arrival: arrival))
        }
    }

    private func handle(_ event: Flow.Event) {
        enqueue(flow.handle(event))
    }

    private func enqueue(_ effects: [Flow.Effect]) {
        for effect in effects {
            if case .apply(let command, let tap) = effect {
                tapped(command, tap)
            } else {
                self.effects.yield(effect)
            }
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
        case .apply:
            // Handed to the engine on the spot, in `enqueue(_:)`.
            break
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

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Read on arrival, before the hop to the main actor, so the 2 s limit measures the trip from the Watch alone.
        let arrival = ClockAnchor<ContinuousClock.Instant>.now
        let id = ObjectIdentifier(workoutSession)
        // Data this build can't read is dropped.
        let messages = data.compactMap { try? MessageFromWatch(json: $0) }
        Task { @MainActor in self.received(messages, from: id, arrival: arrival) }
    }
}
