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

    private let timeline: Timeline
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
        Task { await handOver(armed) }
    }

    /// After every suspension, an old token means this Cue has been replaced, so nothing here applies any more.
    private func handOver(_ armed: ArmedCue) async {
        guard await prepareSession(for: armed) else { return }
        guard clock.now <= armed.deadline.advanced(by: lateLimit) else {
            cueEnded()
            return
        }
        do {
            try await audio.schedule(armed.cue, at: armed.deadline, token: armed.token)
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
        case .interrupted, .resumeRecommended, .routeChanged, .mediaServicesReset:
            break
        }
    }
}
