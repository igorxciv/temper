/// Each Cue goes to audio this far ahead, even with Dip off. On a device the audio clock drifted about 530 ms
/// from `ContinuousClock` over 51 minutes, but at most 3.1 ms across one lead. A full Dip cycle took about 3.2s,
/// so it fits inside the shortest Phase, 00:05, and short Phases need no special case.
private nonisolated let cueLead = Duration.milliseconds(1_500)
private nonisolated let startLimit = Duration.seconds(1)
private nonisolated let lateLimit = Duration.seconds(1)
private nonisolated let liftRetryDelay = Duration.seconds(5)

/// Decides which Cues play and what the audio session does around them. It has its own actor and never waits
/// on audio while the engine waits on it, so a slow audio call can't move a Phase's end.
///
/// Audio calls are made as soon as they're decided, without waiting for the one before, because the audio side
/// carries them out in order. So the session's last decided state is the one it ends up in, and `session`
/// records that as soon as a call is made.
actor CueRules<EngineClock: Clock> where EngineClock.Duration == Duration {
    typealias Instant = EngineClock.Instant

    private enum Session: Equatable {
        case released
        case active(ducked: Bool)
    }

    private struct ArmedCue {
        let cue: Cue
        let deadline: Instant
        let token: CueToken
    }

    private var timeline: Timeline
    private let clock: EngineClock
    private let audio: any AudioOutput<Instant>
    private let isDipOn: Bool

    private var session = Session.released
    /// Whether any activate has been made since the session was last released, even one that failed or never
    /// returned, so a release always follows it.
    private var holdsAudio = false
    private var isFinished = false
    /// When the active time was zero, or `nil` when the Workout isn't running.
    private var origin: Instant?
    /// The earliest due time of any Cue not yet dealt with.
    private var earliestDue = Duration.zero
    private var token = CueToken(value: 0)
    private var armed: ArmedCue?
    /// A Cue that an interruption cut before its deadline, waiting for recovery to schedule it again.
    private var interruptedCue: ArmedCue?
    private var lead: Task<Void, Never>?
    private var liftRetry: Task<Void, Never>?
    private var listening: Task<Void, Never>?
    private var pendingStart: CheckedContinuation<Void, Never>?
    private var startTimeout: Task<Void, Never>?

    init(timeline: Timeline, clock: EngineClock, audio: any AudioOutput<Instant>, isDipOn: Bool) {
        self.timeline = timeline
        self.clock = clock
        self.audio = audio
        self.isDipOn = isDipOn
    }

    // MARK: Start

    /// Returns once audio is ready, or has failed, or `startLimit` has passed.
    func prepareToStart() async {
        let ducking = isDipOn && timeline.position(at: .zero).nextCue?.due == .zero
        let limit = clock.now.advanced(by: startLimit)
        session = .active(ducked: ducking)
        holdsAudio = true
        listenForEvents()
        await withCheckedContinuation { continuation in
            pendingStart = continuation
            Task {
                let isActive = (try? await audio.activate(ducking: ducking)) != nil
                settleStart(isActive: isActive)
            }
            startTimeout = Task { [clock] in
                try? await clock.sleep(until: limit, tolerance: sleepTolerance)
                guard !Task.isCancelled else { return }
                settleStart(isActive: false)
            }
        }
    }

    private func settleStart(isActive: Bool) {
        guard let pendingStart else { return }
        self.pendingStart = nil
        startTimeout?.cancel()
        if !isActive {
            session = .released
        }
        pendingStart.resume()
    }

    /// Begins handing over Cues, counting active time from `origin`.
    func run(from origin: Instant) {
        self.origin = origin
        handOverNextCue()
    }

    // MARK: Pause and Stop

    /// Any Cue due at or before the tap has had its moment, so Resume won't repeat it. A later one was only
    /// waiting, so Resume schedules it again.
    func pause(at tap: Instant) {
        guard let origin else { return }
        earliestDue = origin.duration(to: tap) + .nanoseconds(1)
        releaseSession()
    }

    /// Restarts audio undipped, unless the next Cue's lead has already begun, in which case arming it
    /// restarts audio the way that Cue needs.
    func resume(from origin: Instant) {
        self.origin = origin
        holdsAudio = true
        if nextCue(from: origin).map({ $0.leadStart > clock.now }) ?? true {
            let resumeToken = token
            session = .active(ducked: false)
            Task {
                guard (try? await audio.activate(ducking: false)) == nil, resumeToken == token else { return }
                session = .released
            }
        }
        handOverNextCue()
    }

    /// Done has placed the Phases after the open one, so the next Cue is worked out again, as on Resume. The Cue
    /// Done brings is due at the tap, and its lead has passed, so it's armed at once and plays only if audio can
    /// start it within `lateLimit` of the tap, like any late Cue.
    func done(timeline: Timeline) {
        self.timeline = timeline
        handOverNextCue()
    }

    func stop() {
        settleStart(isActive: false)
        releaseSession()
        listening?.cancel()
    }

    /// Plays a "Workout complete" that's up to `lateLimit` late, then holds the session until it has ended.
    func finish() {
        isFinished = true
        handOverNextCue()
        origin = nil
        if armed == nil {
            stop()
        }
    }

    /// Cuts any armed Cue and lets go of the session. A new token means every call still out there is ignored
    /// when it returns.
    private func releaseSession() {
        let cutsCue = armed != nil
        let deactivates = holdsAudio
        token = CueToken(value: token.value + 1)
        armed = nil
        interruptedCue = nil
        origin = nil
        lead?.cancel()
        liftRetry?.cancel()
        session = .released
        holdsAudio = false
        Task {
            if cutsCue {
                try? await audio.cancel()
            }
            if deactivates {
                try? await audio.deactivate()
            }
        }
    }

    // MARK: Handing Cues over

    private func nextCue(from origin: Instant) -> (upcoming: UpcomingCue, deadline: Instant, leadStart: Instant)? {
        let activeTime = origin.duration(to: clock.now)
        let earliest = max(earliestDue, activeTime - lateLimit)
        guard let upcoming = timeline.position(at: earliest).nextCue else { return nil }
        let deadline = origin.advanced(by: upcoming.due)
        return (upcoming, deadline, deadline.advanced(by: .zero - cueLead))
    }

    /// Arms the next Cue if its lead has begun, and otherwise wakes when it does. A wake at any other time
    /// works it out again from the clock.
    private func handOverNextCue() {
        lead?.cancel()
        guard let origin, let (upcoming, deadline, leadStart) = nextCue(from: origin) else { return }
        if leadStart <= clock.now {
            earliestDue = upcoming.due + .nanoseconds(1)
            arm(upcoming.cue, at: deadline)
            handOverNextCue()
        } else {
            lead = Task { [clock] in
                try? await clock.sleep(until: leadStart, tolerance: sleepTolerance)
                guard !Task.isCancelled else { return }
                handOverNextCue()
            }
        }
    }

    private func arm(_ cue: Cue, at deadline: Instant) {
        liftRetry?.cancel()
        token = CueToken(value: token.value + 1)
        let armed = ArmedCue(cue: cue, deadline: deadline, token: token)
        self.armed = armed
        interruptedCue = nil
        Task { await handOver(armed) }
    }

    /// After every suspension, an old token means this Cue has been replaced, so nothing here applies any more.
    /// Getting the session ready is the recovery that runs before each Cue. A call holds the Cue back the way
    /// an interruption does, so it plays if the call ends and recovery comes in time.
    private func handOver(_ armed: ArmedCue) async {
        let isOnCall = await audio.isOnCall()
        guard armed.token == token else { return }
        guard !isOnCall else {
            if !isFinished, clock.now < armed.deadline {
                interruptedCue = armed
            }
            session = .released
            cueEnded()
            return
        }
        guard await prepareSession(for: armed) else { return }
        let latest = armed.deadline.advanced(by: lateLimit)
        guard clock.now <= latest else {
            cueEnded()
            return
        }
        do {
            // Audio can take a while to start after this check, so it's told the latest start as well.
            try await audio.schedule(armed.cue, at: armed.deadline, startingBy: latest, token: armed.token)
        } catch {
            guard armed.token == token else { return }
            if session == .active(ducked: false) {
                session = .released
            }
            cueEnded()
        }
    }

    /// Returns whether the Cue is still current and has a session to play in. A failed Dip falls back to an
    /// undipped session, because Cues win over Dip.
    private func prepareSession(for armed: ArmedCue) async -> Bool {
        guard session != .active(ducked: isDipOn) else { return true }
        for ducking in isDipOn ? [true, false] : [false] {
            session = .active(ducked: ducking)
            if (try? await audio.activate(ducking: ducking)) != nil {
                return armed.token == token
            }
            guard armed.token == token else { return false }
        }
        session = .released
        cueEnded()
        return false
    }

    /// The current Cue has finished speaking, or won't speak at all.
    private func cueEnded() {
        armed = nil
        if isFinished {
            stop()
        } else if session == .active(ducked: true) {
            lift(retryingAfterFailure: true)
        }
    }

    private func lift(retryingAfterFailure: Bool) {
        let liftToken = token
        let retryAt = clock.now.advanced(by: liftRetryDelay)
        session = .active(ducked: false)
        Task {
            guard (try? await audio.activate(ducking: false)) == nil, liftToken == token else { return }
            session = .active(ducked: true)
            guard retryingAfterFailure else { return }
            liftRetry = Task { [clock] in
                try? await clock.sleep(until: retryAt, tolerance: sleepTolerance)
                guard !Task.isCancelled else { return }
                lift(retryingAfterFailure: false)
            }
        }
    }

    // MARK: Events

    private func listenForEvents() {
        listening = Task {
            for await event in audio.events {
                handle(event)
            }
        }
    }

    private func handle(_ event: AudioEvent) {
        switch event {
        case .cueFinished(let finished):
            if finished == armed?.token {
                cueEnded()
            }
        case .interrupted, .mediaServicesReset:
            interrupt()
        case .resumeRecommended:
            recover()
        case .routeChanged:
            restartOnNewRoute()
        }
    }

    // MARK: Interruptions and recovery

    /// iOS has taken the session away, and the Workout carries on regardless. A Cue cut before its deadline waits
    /// for recovery. One cut after its deadline has started speaking, so it's never restarted, because a
    /// repeated word would be taken for a new Phase change.
    private func interrupt() {
        guard holdsAudio else { return }
        token = CueToken(value: token.value + 1)
        liftRetry?.cancel()
        session = .released
        guard let cut = armed else { return }
        armed = nil
        interruptedCue = clock.now < cut.deadline ? cut : nil
        Task { try? await audio.cancel() }
        if isFinished {
            stop()
        }
    }

    /// Runs when iOS recommends resuming, on returning to the front, and through `handOver` before each Cue. It
    /// does nothing while audio is in use or a call is on. A Cue cut before its deadline is scheduled again if
    /// this is no more than `lateLimit` after that deadline. A Dip still down after its lift failed is lifted.
    /// A failure waits for the next trigger, so recovery never loops. Triggers can overlap, but only the first
    /// to pass the call check finds audio still to recover.
    func recover() {
        guard isAwaitingRecovery || isDipLeftDown else { return }
        let recoveryToken = token
        Task {
            let isOnCall = await audio.isOnCall()
            guard !isOnCall, recoveryToken == token else { return }
            if isDipLeftDown {
                liftRetry?.cancel()
                lift(retryingAfterFailure: false)
                return
            }
            guard isAwaitingRecovery else { return }
            if let cut = interruptedCue.take(), clock.now <= cut.deadline.advanced(by: lateLimit) {
                arm(cut.cue, at: cut.deadline)
                return
            }
            session = .active(ducked: false)
            guard (try? await audio.activate(ducking: false)) == nil, recoveryToken == token else { return }
            session = .released
        }
    }

    /// A running Workout with no session and no Cue under way. A Cue under way gets its own session.
    private var isAwaitingRecovery: Bool {
        origin != nil && session == .released && armed == nil
    }

    /// A running Workout whose music is still dipped with no Cue under way, because lifting the Dip failed.
    private var isDipLeftDown: Bool {
        origin != nil && session == .active(ducked: true) && armed == nil
    }

    /// The adapter has stopped the engine for the new route. Restarting it is an interruption and an immediate
    /// recovery, so the armed Cue follows the same two rules.
    private func restartOnNewRoute() {
        guard holdsAudio, session != .released else { return }
        interrupt()
        recover()
    }
}
