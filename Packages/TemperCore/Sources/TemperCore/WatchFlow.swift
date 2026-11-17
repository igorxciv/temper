import Foundation

/// The Watch's side of the running link, as a pure value: each event in, the effects for the session adapter out,
/// and the screen to show.
///
/// The iPhone opens the Watch at Start. The Watch starts its own workout session and follows what the iPhone sends.
/// It keeps no Workout logic of its own and persists nothing. Its capsule and secondary page are a remote: each tap
/// goes to the iPhone dated when it was made, and the update it causes shows it worked. Its session pauses and resumes
/// with each update, and while it runs the Watch taps the wrist at each Cue. The session is there for the heart rate,
/// and to keep the Watch app awake and reachable with the wrist down. It saves nothing: at the end the Watch discards
/// what it collected, because Temper makes no Health workouts.
///
/// The link dropping starts a dropout. The Watch says so, refuses taps and plays no haptics, while its session runs
/// on. Any message from the iPhone ends the dropout, and the update that follows `begin` on every reconnect puts the
/// screen right. If nothing comes for ``outOfContactLimit``, the Watch ends its session and goes back to idle. It does
/// the same when another workout app takes its session over.
///
/// Connecting and a dropout can each last for up to 10 minutes with the iPhone app gone, so both offer End, which ends
/// the Watch's session and goes back to idle. The iPhone sees the session end, and its Workout runs on.
///
/// A Watch whose session reached the iPhone after the 10 s window is late. It doesn't join the Workout under way: it
/// ends its session and goes back to idle.
public nonisolated struct WatchFlow: Equatable, Sendable {
    public enum Screen: Equatable, Sendable {
        /// "Start on iPhone", or the Health hint when workouts aren't allowed.
        case idle
        /// "Connecting to iPhone", from the iPhone's request until its first update.
        case waiting
        /// A Phase, with whether the iPhone is in contact. During a dropout the Watch keeps drawing the Phase it last
        /// heard, with "iPhone not connected" and its controls dimmed.
        case running(WatchPhase, isConnected: Bool)
        /// The iPhone's complete screen, shrunk, until the owner taps Done.
        case complete(Completion)
        /// The iPhone sends a version of the messages this Watch can't follow.
        case updateNeeded
    }

    public enum Event: Equatable, Sendable {
        /// The iPhone opened the Watch for a Workout, with `workoutsAllowed` read from the Watch's own Health status.
        case launched(workoutsAllowed: Bool)
        /// HealthKit handed back the session of a Watch app that crashed, with whether that session is paused.
        case recovered(isPaused: Bool)
        /// A message from the iPhone arrived, at `at` on the Watch's clock.
        case received(MessageToWatch, at: Date)
        /// The link to the iPhone dropped, at `at` on the Watch's clock.
        case disconnected(at: Date)
        /// ``outOfContactLimit`` has passed since `startOutOfContactTimer`, with no `stopOutOfContactTimer`.
        case outOfContactTimerFired
        /// The session stopped, from the iPhone's side or the Watch's.
        case sessionStopped
        /// The session ended, and the link with it. If the Watch didn't end it, the system did, as it does when
        /// another workout app starts a session of its own.
        case sessionEnded
        /// The owner tapped Done on the complete screen.
        case doneTapped
        /// The owner tapped End while the Watch was connecting or out of contact, which may last because the iPhone
        /// app has gone.
        case endTapped
        /// The time `awaitFirstMessage` gave the iPhone's first message ran out.
        case firstMessageTimedOut
        /// The owner tapped the capsule or the secondary page at `date` on the Watch's clock.
        case tapped(WatchCommand, at: Date)
    }

    public enum Effect: Equatable, Sendable {
        /// Start a workout session, and mirror it to the iPhone once it's prepared.
        case startSession
        /// Report `firstMessageTimedOut` once this long has passed, in place of any earlier wait.
        case awaitFirstMessage(for: Duration)
        /// Begin the session's collection at the Workout's Start, so the heart rate it reports spans the Workout.
        case beginCollection(at: Date)
        /// Pause the session, so it stops counting active time and energy.
        case pauseSession
        case resumeSession
        /// Discard what the session collected and end it. The session may have ended already, taken over by another
        /// workout app.
        case endWithoutSaving
        /// Send a message to the iPhone over the session.
        case send(MessageFromWatch)
        /// Show that a tap failed: the iPhone refused it, having got it too late to place, or a dropout kept it from
        /// being sent.
        case signalRefused(WatchCommand)
        /// Start timing ``outOfContactLimit``, and report `outOfContactTimerFired` once it has passed.
        case startOutOfContactTimer
        case stopOutOfContactTimer
        /// Cancel every Cue's haptic scheduled for after `after`. One due by then has started, and plays out.
        case cancelHaptics(after: Date)
        /// Cancel every Cue's haptic, under way or still to come, as the session or the link goes.
        case cancelAllHaptics
        /// Play a Cue's haptic now.
        case playHaptic(Cue)
        /// Play each Cue's haptic at its date.
        case scheduleHaptics([WatchCue])
    }

    /// How long a session waits for the iPhone's first message before it ends without saving.
    public static var firstMessageTimeout: Duration { .seconds(600) }

    /// How long a dropout lasts before the Watch ends its session. It's time out of contact, not time since the last
    /// update, so a long open Work can't set it off.
    public static var outOfContactLimit: Duration { .seconds(600) }

    public private(set) var screen = Screen.idle
    /// The Workout the iPhone's `begin` tied the session to, or `nil` before it.
    private var workoutID: UUID?
    /// True from starting a session until it's told to end, or ends by itself, so it's ended only once.
    private var hasSession = false
    /// Whether the session was last told to pause rather than resume.
    private var isSessionPaused = false
    /// The haptics the updates have scheduled and played, which only a running session can play with the wrist down.
    private var haptics = CueHaptics()
    /// When the link dropped, or `nil` while the iPhone is in contact.
    private var lostContact: Date?

    public init() {}

    public mutating func handle(_ event: Event) -> [Effect] {
        switch event {
        case .launched(let workoutsAllowed):
            guard workoutsAllowed else { return [] }
            let ending = endSession()
            follow(isPaused: false)
            return ending + [.startSession, .awaitFirstMessage(for: Self.firstMessageTimeout)]
        case .recovered(let isPaused):
            follow(isPaused: isPaused)
            // A recovered session has no Workout tied to it either, until the iPhone's fresh `begin`.
            return [.awaitFirstMessage(for: Self.firstMessageTimeout)]
        case .received(let message, let arrival):
            return receive(message, at: arrival)
        case .disconnected(let date):
            guard hasSession, workoutID != nil, lostContact == nil else { return [] }
            lostContact = date
            if case .running(let phase, _) = screen {
                screen = .running(phase, isConnected: false)
            }
            return cancelHaptics() + [.startOutOfContactTimer]
        case .outOfContactTimerFired:
            guard lostContact != nil else { return [] }
            // The timer has run out, so there's none to stop.
            lostContact = nil
            leaveRunning()
            return endSession()
        case .sessionStopped:
            // The iPhone stops a session tied to a Workout only after sending `end`, which can arrive just after the
            // stop. So that session waits for it, and only a session tied to nothing ends here.
            guard workoutID == nil else { return [] }
            return endSession()
        case .sessionEnded:
            // A session tied to a Workout that the Watch didn't end still has what it collected to discard.
            guard hasSession, workoutID != nil else {
                hasSession = false
                leaveRunning()
                return []
            }
            leaveRunning()
            return endSession()
        case .doneTapped:
            if case .complete = screen {
                screen = .idle
            }
            return []
        case .endTapped:
            // In contact, Stop ends the Workout itself, so End is only for a Watch with no iPhone to answer.
            switch screen {
            case .waiting, .running(_, isConnected: false):
                leaveRunning()
                return endSession()
            case .idle, .running, .complete, .updateNeeded:
                return []
            }
        case .firstMessageTimedOut:
            // A session tied to a Workout has had its first message. One still tied to nothing never began
            // collection, so it has nothing to save.
            guard hasSession, workoutID == nil else { return [] }
            leaveRunning()
            return endSession()
        case .tapped(let command, let date):
            guard case .running(_, let isConnected) = screen else { return [] }
            return isConnected ? [.send(.tap(command, at: date))] : [.signalRefused(command)]
        }
    }

    /// Starts following a session, new or recovered, that no Workout is tied to yet.
    private mutating func follow(isPaused: Bool) {
        self = Self()
        screen = .waiting
        hasSession = true
        isSessionPaused = isPaused
    }

    private mutating func receive(_ message: MessageToWatch, at arrival: Date) -> [Effect] {
        guard screen != .updateNeeded else { return [] }
        // Any message means the iPhone is back.
        return regainContact() + act(on: message, at: arrival)
    }

    private mutating func act(on message: MessageToWatch, at arrival: Date) -> [Effect] {
        switch message {
        case .begin(let workoutID, let start, _, let inTime, _, let version):
            guard version == MessageToWatch.version else {
                screen = .updateNeeded
                return endSession()
            }
            guard workoutID != self.workoutID else { return [] }
            guard inTime else {
                // A late Watch doesn't join the Workout under way. Starting afresh, it ignores what follows.
                let ending = endSession()
                self = Self()
                return ending
            }
            self.workoutID = workoutID
            // The Watch waits on for the update with its first Phase.
            return [.beginCollection(at: start)]
        case .update(let state):
            guard workoutID != nil else { return [] }
            show(state)
            guard hasSession else { return [] }
            return followPause(of: state) + hapticEffects(for: state, at: arrival)
        case .refused(let command):
            guard workoutID != nil else { return [] }
            return [.signalRefused(command)]
        case .end:
            guard workoutID != nil else { return [] }
            leaveRunning()
            return endSession()
        case .discard:
            // The session belongs to no running Workout.
            leaveRunning()
            return endSession()
        }
    }

    private mutating func show(_ state: WatchState) {
        switch state {
        case .phase(let phase): screen = .running(phase, isConnected: true)
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

    /// Ends a dropout, if one is on.
    private mutating func regainContact() -> [Effect] {
        guard lostContact != nil else { return [] }
        lostContact = nil
        if case .running(let phase, _) = screen {
            screen = .running(phase, isConnected: true)
        }
        return [.stopOutOfContactTimer]
    }

    /// Pauses or resumes the session when a running Phase's pause changes. An ended Workout leaves it as it is, since
    /// `end` follows.
    private mutating func followPause(of state: WatchState) -> [Effect] {
        guard case .phase(let phase) = state else { return [] }
        let isPaused = phase.pausedAt != nil
        guard isPaused != isSessionPaused else { return [] }
        isSessionPaused = isPaused
        return [isPaused ? .pauseSession : .resumeSession]
    }

    /// Ends the session once, and any dropout with it, discarding what it collected.
    private mutating func endSession() -> [Effect] {
        guard hasSession else { return [] }
        hasSession = false
        return regainContact() + cancelHaptics() + [.endWithoutSaving]
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

    /// The session or the link is going, so no haptic still to come can play.
    private mutating func cancelHaptics() -> [Effect] {
        haptics.cancelAll() ? [.cancelAllHaptics] : []
    }
}
