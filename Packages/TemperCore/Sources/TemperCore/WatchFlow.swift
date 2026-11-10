import Foundation

/// The Watch's side of the running link, as a pure value: each event in, the effects for the session adapter out,
/// and the screen to show.
///
/// The iPhone opens the Watch at Start. The Watch starts its own workout session and follows what the iPhone sends.
/// It keeps no Workout logic of its own and persists nothing. For now it displays the Workout and taps the wrist at each
/// Cue: it ends its session without saving, so the iPhone's own Health workout covers every Workout.
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
        /// A message from the iPhone arrived, at `at` on the Watch's clock.
        case received(MessageToWatch, at: Date)
        /// The session stopped, from the iPhone's side or the Watch's.
        case sessionStopped
        /// The session ended, and the link with it.
        case sessionEnded
        /// The owner tapped Done on the complete screen.
        case doneTapped
    }

    public enum Effect: Equatable, Sendable {
        /// Start a workout session, and mirror it to the iPhone once it's prepared.
        case startSession
        /// Begin the session's collection at the Workout's Start, so the Watch's copy spans what the iPhone's does.
        case beginCollection(at: Date)
        /// Discard what the session collected and end it.
        case endWithoutSaving
        /// Cancel every Cue's haptic scheduled for after `after`. One due by then has started, and plays out.
        case cancelHaptics(after: Date)
        /// Play a Cue's haptic now.
        case playHaptic(Cue)
        /// Play each Cue's haptic at its date.
        case scheduleHaptics([WatchCue])
    }

    public private(set) var screen = Screen.idle
    /// The Workout the iPhone's `begin` tied the session to, or `nil` before it.
    private var workoutID: UUID?
    /// True from starting a session until it's told to end, or ends by itself, so it's ended only once.
    private var hasSession = false
    /// The haptics the updates have scheduled and played, which only a running session can play with the wrist down.
    private var haptics = CueHaptics()

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
        case .received(let message, let arrival):
            return receive(message, at: arrival)
        case .sessionStopped:
            return endSession()
        case .sessionEnded:
            hasSession = false
            leaveRunning()
            return cancelHaptics()
        case .doneTapped:
            if case .complete = screen {
                screen = .idle
            }
            return []
        }
    }

    private mutating func receive(_ message: MessageToWatch, at arrival: Date) -> [Effect] {
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
            return hasSession ? hapticEffects(for: state, at: arrival) : []
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
        return cancelHaptics() + [.endWithoutSaving]
    }

    private mutating func hapticEffects(for state: WatchState, at arrival: Date) -> [Effect] {
        let plan = haptics.plan(for: state, arrivingAt: arrival)
        var effects: [Effect] = []
        if plan.cancelsScheduled {
            effects.append(.cancelHaptics(after: arrival))
        }
        if let cue = plan.playsNow {
            effects.append(.playHaptic(cue))
        }
        if !plan.schedules.isEmpty {
            effects.append(.scheduleHaptics(plan.schedules))
        }
        return effects
    }

    /// The session is going, so no haptic still to come can play.
    private mutating func cancelHaptics() -> [Effect] {
        haptics.cancelAll() ? [.cancelHaptics(after: .distantPast)] : []
    }
}
