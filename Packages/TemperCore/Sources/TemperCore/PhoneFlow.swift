import Foundation

/// The iPhone's side of the running link, as a pure value: each event in, the effects for `WatchLink` out.
///
/// At Start the iPhone opens the Watch, whose workout session arrives back as a mirrored instance. Every instance
/// that started at or after the running Workout's Start belongs to it, and gets `begin`, then the latest update, then
/// `end` once the Workout has ended, after which the iPhone stops the session. So a Watch that reconnects catches up
/// the same way as one arriving for the first time. For now `end` never carries a record, so the Watch saves nothing
/// and the iPhone's own Health workout covers every Workout.
///
/// The instance is generic so tests can stand in for HealthKit's session.
public nonisolated struct PhoneFlow<Instance: Hashable & Sendable>: Sendable {
    public enum Event: Equatable, Sendable {
        /// The engine set the Workout's fixed start point, at `start` on the wall clock. `workoutsAllowed` is the
        /// iPhone's workout write status, which is also the Watch's.
        case started(workoutID: UUID, workoutType: WorkoutType, start: Date, workoutsAllowed: Bool)
        /// The Watch's state after an engine event.
        case published(WatchState)
        /// A mirrored session arrived, which started on the Watch at `start` and reached the iPhone `at`.
        case instanceArrived(Instance, start: Date, at: Date)
        /// A mirrored session reached its end, so the link through it is gone.
        case instanceEnded(Instance)
    }

    public enum Effect: Equatable, Sendable {
        /// Ask the Watch to open and start its session. Start never waits for it.
        case startWatchApp
        /// Send a message, in order after the effects before it.
        case send(MessageToWatch, to: Instance)
        /// Stop the Watch's session from this side, once the messages before it have been sent.
        case stopActivity(Instance)
    }

    private struct Running: Sendable {
        let workoutID: UUID
        let workoutType: WorkoutType
        let start: Date
    }

    /// How long after Start a Watch session can arrive and still be in time for the Watch's controls. The engine's
    /// start point and the request to open the Watch are moments apart, so the window is timed from the start point.
    public static var window: Duration { .seconds(10) }

    private var running: Running?
    /// The latest state published, which each newly arrived session gets after `begin`.
    private var latest: WatchState?
    /// The session that belongs to the running Workout, or `nil` while there's none.
    private var current: Instance?
    /// Whether the Watch's first session arrived within ``window``, fixed then for the rest of the Workout.
    private var inTime: Bool?

    public init() {}

    public mutating func handle(_ event: Event) -> [Effect] {
        switch event {
        case .started(let workoutID, let workoutType, let start, let workoutsAllowed):
            self = Self()
            running = Running(workoutID: workoutID, workoutType: workoutType, start: start)
            return workoutsAllowed ? [.startWatchApp] : []
        case .published(let state):
            guard running != nil else { return [] }
            let hadEnded = hasEnded
            latest = state
            guard let current else { return [] }
            return [.send(.update(state), to: current)] + (hadEnded ? [] : ending(current))
        case .instanceArrived(let instance, let start, let arrival):
            guard let running, start >= running.start else { return [] }
            current = instance
            let inTime = inTime ?? (arrival.timeIntervalSince(running.start) <= Self.window / .seconds(1))
            self.inTime = inTime
            let begin = MessageToWatch.begin(
                workoutID: running.workoutID, start: running.start, workoutType: running.workoutType,
                inTime: inTime, version: MessageToWatch.version)
            return [.send(begin, to: instance)] + (latest.map { [.send(.update($0), to: instance)] } ?? [])
                + ending(instance)
        case .instanceEnded(let instance):
            if current == instance {
                current = nil
            }
            return []
        }
    }

    private var hasEnded: Bool {
        if case .ended = latest { true } else { false }
    }

    /// Once the Workout has ended, `end` and a stop for `instance`, which by then has the ended state.
    private func ending(_ instance: Instance) -> [Effect] {
        hasEnded ? [.send(.end(nil), to: instance), .stopActivity(instance)] : []
    }
}
