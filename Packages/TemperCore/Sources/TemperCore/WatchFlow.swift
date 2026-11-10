import Foundation

/// The Watch's side of the running link, as a pure value: each event in, the effects for the session adapter out,
/// and the screen to show.
///
/// The iPhone opens the Watch at Start. The Watch starts its own workout session and follows what the iPhone sends.
/// It keeps no Workout logic of its own and persists nothing. Its capsule and secondary page are a remote: each tap
/// goes to the iPhone dated when it was made, and the update it causes shows it worked. For now the Watch ends its
/// session without saving, so the iPhone's own Health workout covers every Workout.
public nonisolated struct WatchFlow: Equatable, Sendable {
    public enum Screen: Equatable, Sendable {
        /// "Start on iPhone", or the Health hint when workouts aren't allowed.
        case idle
        /// "Connecting to iPhone", from the iPhone's request until its first update.
        case waiting
        case running(WatchPhase)
        /// The iPhone's complete screen, shrunk, until the owner taps Done.
        case complete(Completion)
        /// The iPhone sends a version of the messages this Watch can't follow.
        case updateNeeded
    }

    public enum Event: Equatable, Sendable {
        /// The iPhone opened the Watch for a Workout, with `workoutsAllowed` read from the Watch's own Health status.
        case launched(workoutsAllowed: Bool)
        case received(MessageToWatch)
        /// The session stopped, from the iPhone's side or the Watch's.
        case sessionStopped
        /// The session ended, and the link with it.
        case sessionEnded
        /// The owner tapped Done on the complete screen.
        case doneTapped
        /// The owner tapped the capsule or the secondary page at `date` on the Watch's clock.
        case tapped(WatchCommand, at: Date)
    }

    public enum Effect: Equatable, Sendable {
        /// Start a workout session, and mirror it to the iPhone once it's prepared.
        case startSession
        /// Begin the session's collection at the Workout's Start, so the Watch's copy spans what the iPhone's does.
        case beginCollection(at: Date)
        /// Discard what the session collected and end it.
        case endWithoutSaving
        /// Send a message to the iPhone over the session.
        case send(MessageFromWatch)
        /// Show that the iPhone refused a tap, which reached it too late to place.
        case signalRefused(WatchCommand)
    }

    public private(set) var screen = Screen.idle
    /// The Workout the iPhone's `begin` tied the session to, or `nil` before it.
    private var workoutID: UUID?
    /// True from starting a session until it's told to end, or ends by itself, so it's ended only once.
    private var hasSession = false

    public init() {}

    public mutating func handle(_ event: Event) -> [Effect] {
        switch event {
        case .launched(let workoutsAllowed):
            guard workoutsAllowed else { return [] }
            let ending = endSession()
            screen = .waiting
            workoutID = nil
            hasSession = true
            return ending + [.startSession]
        case .received(let message):
            return receive(message)
        case .sessionStopped:
            return endSession()
        case .sessionEnded:
            hasSession = false
            leaveRunning()
            return []
        case .doneTapped:
            if case .complete = screen {
                screen = .idle
            }
            return []
        case .tapped(let command, let date):
            guard case .running = screen else { return [] }
            return [.send(.tap(command, at: date))]
        }
    }

    private mutating func receive(_ message: MessageToWatch) -> [Effect] {
        guard screen != .updateNeeded else { return [] }
        switch message {
        case .begin(let workoutID, let start, _, _, let version):
            guard version == MessageToWatch.version else {
                screen = .updateNeeded
                return endSession()
            }
            guard workoutID != self.workoutID else { return [] }
            self.workoutID = workoutID
            return [.beginCollection(at: start)]
        case .update(let state):
            guard workoutID != nil else { return [] }
            show(state)
            return []
        case .refused(let command):
            guard workoutID != nil else { return [] }
            return [.signalRefused(command)]
        case .end:
            guard workoutID != nil else { return [] }
            leaveRunning()
            return endSession()
        }
    }

    private mutating func show(_ state: WatchState) {
        switch state {
        case .phase(let phase): screen = .running(phase)
        case .ended(let completion?): screen = .complete(completion)
        case .ended(nil): screen = .idle
        }
    }

    /// Nothing is left to follow, so a Watch still waiting or running goes back to idle. A complete screen waits for
    /// Done, and "Update Temper" stays.
    private mutating func leaveRunning() {
        switch screen {
        case .waiting, .running: screen = .idle
        case .idle, .complete, .updateNeeded: break
        }
    }

    private mutating func endSession() -> [Effect] {
        guard hasSession else { return [] }
        hasSession = false
        return [.endWithoutSaving]
    }
}
