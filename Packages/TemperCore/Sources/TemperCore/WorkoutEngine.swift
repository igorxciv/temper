nonisolated let sleepTolerance = Duration.milliseconds(10)

/// Runs one Workout from one fixed start point. It publishes a snapshot only on an event, and works out
/// where the Workout is from the clock each time, so a late wake can't build up any error.
public actor WorkoutEngine<EngineClock: Clock> where EngineClock.Duration == Duration {
    public typealias Instant = EngineClock.Instant
    public typealias Snapshot = WorkoutSnapshot<Instant>

    private enum State {
        case ready
        case starting
        case running(start: Instant, heldFor: Duration)
        case paused(start: Instant, heldFor: Duration, since: Instant)
        case ended
    }

    /// Ends after the snapshot for a finished or stopped Workout.
    public nonisolated let snapshots: AsyncStream<Snapshot>

    private let continuation: AsyncStream<Snapshot>.Continuation
    private let clock: EngineClock
    private var timeline: Timeline
    private let rounds: Int?
    private let cueRules: CueRules<EngineClock>
    private var state = State.ready
    /// Each Pause that has been Resumed, from its tap to its Resume, kept for the Workout record.
    private var pauses: [Range<Instant>] = []
    private var latest: Snapshot?
    private var wake: Task<Void, Never>?

    /// One engine runs one Workout, so `isDipOn` is the Dip setting as it was when that Workout started.
    public init(workout: Workout, clock: EngineClock, audio: any AudioOutput<Instant>, isDipOn: Bool) {
        (snapshots, continuation) = AsyncStream.makeStream()
        self.clock = clock
        timeline = Timeline(workout: workout)
        rounds = workout.rounds
        cueRules = CueRules(timeline: timeline, clock: clock, audio: audio, isDipOn: isDipOn)
    }

    /// Waits for audio, for at most a second, then sets the fixed start point.
    public func start() async {
        guard case .ready = state else { return }
        state = .starting
        await cueRules.prepareToStart()
        guard case .starting = state else { return }
        let start = clock.now
        state = .running(start: start, heldFor: .zero)
        await cueRules.run(from: start)
        await recalculate()
    }

    /// Pause keeps the time of the tap, so nothing the engine is busy with can shift the time left.
    public func pause(at tap: Instant) async {
        guard case .running(let start, let heldFor) = state else { return }
        let position = timeline.position(at: start.duration(to: tap) - heldFor)
        guard let phase = position.phase else {
            await finish(start: start, heldFor: heldFor)
            return
        }
        wake?.cancel()
        state = .paused(start: start, heldFor: heldFor, since: tap)
        let progress: Snapshot.Progress =
            phase.isOpen
            ? .pausedOpen(phase: phase, elapsed: position.elapsed)
            : .paused(phase: phase, timeLeft: position.timeLeft)
        publish(snapshot(progress, at: position))
        await cueRules.pause(at: tap)
    }

    /// Resume keeps the time of the tap, so the Pause's length is exactly what the owner held it for.
    public func resume(at tap: Instant) async {
        guard case .paused(let start, let heldFor, let since) = state else { return }
        let held = heldFor + since.duration(to: tap)
        pauses.append(since..<tap)
        state = .running(start: start, heldFor: held)
        await cueRules.resume(from: start.advanced(by: held))
        await recalculate()
    }

    /// Done keeps the time of the tap, so the next Phase starts when the owner ended the open one, not when the
    /// tap arrived. It applies only to a running open Phase. A Done during a Phase with a set length, a second tap
    /// of a double tap, or one after Stop or the finish does nothing. So does a Done while Paused, so the owner
    /// resumes before ending a Work and a stray tap can't end it.
    public func done(at tap: Instant) async {
        guard case .running(let start, let heldFor) = state,
            let marked = timeline.markingDone(at: start.duration(to: tap) - heldFor)
        else { return }
        timeline = marked
        await cueRules.done(timeline: marked)
        await recalculate()
    }

    /// Stop keeps the time of the tap, so the Workout record ends where the owner Stopped it: a Phase cut short and a
    /// Pause still on both end at the tap. A tap that arrives after the Workout's finish ends it at the finish.
    public func stop(at tap: Instant) async {
        switch state {
        case .ready, .starting:
            await end(.stopped(WorkoutRecord(start: tap, end: tap, pauses: [], phases: [])))
        case .running(let start, let heldFor):
            // A tap can't land before the Resume the engine already heard, nor past the finish.
            var end = max(tap, pauses.last?.upperBound ?? start)
            if let finish = timeline.finish, start.duration(to: end) - heldFor > finish {
                end = start.advanced(by: finish + heldFor)
            }
            await self.end(.stopped(record(start: start, pauses: pauses, end: end)))
        case .paused(let start, _, let since):
            let end = max(tap, since)
            await self.end(.stopped(record(start: start, pauses: pauses + [since..<end], end: end)))
        case .ended:
            break
        }
    }

    /// For returning to the front: works out where the Workout is and always publishes it, because a
    /// suspended app isn't woken by its own timer. A running Workout also gets its audio back, if iOS took it.
    public func refresh() async {
        guard let snapshot = latest else { return }
        switch state {
        case .running:
            latest = nil
            await recalculate()
            await cueRules.recover()
        case .paused:
            continuation.yield(snapshot)
        case .ready, .starting, .ended:
            break
        }
    }

    /// Works out where the Workout is now. Only a change of Phase or the finish publishes anything. An open Phase
    /// has no end to wake for, so it waits for the next event.
    private func recalculate() async {
        guard case .running(let start, let heldFor) = state else { return }
        let now = clock.now
        let position = timeline.position(at: start.duration(to: now) - heldFor)
        guard let phase = position.phase else {
            await finish(start: start, heldFor: heldFor)
            return
        }
        guard !phase.isOpen else {
            wake?.cancel()
            let startedAt = now.advanced(by: .zero - position.elapsed)
            publish(snapshot(.runningOpen(phase: phase, startedAt: startedAt), at: position))
            return
        }
        let endsAt = now.advanced(by: position.timeLeft)
        publish(snapshot(.running(phase: phase, endsAt: endsAt), at: position))
        wakeUp(at: endsAt)
    }

    private func snapshot(_ progress: Snapshot.Progress, at position: Timeline.Position) -> Snapshot {
        Snapshot(progress: progress, rounds: rounds, previousOpenPhaseTime: position.previousOpenPhaseTime)
    }

    private func wakeUp(at deadline: Instant) {
        wake?.cancel()
        wake = Task { [clock, weak self] in
            try? await clock.sleep(until: deadline, tolerance: sleepTolerance)
            guard !Task.isCancelled else { return }
            await self?.recalculate()
        }
    }

    private func publish(_ snapshot: Snapshot) {
        guard snapshot != latest else { return }
        latest = snapshot
        continuation.yield(snapshot)
    }

    /// Ends the Workout at its finish, however late the engine notices it.
    private func finish(start: Instant, heldFor: Duration) async {
        let end = start.advanced(by: (timeline.finish ?? .zero) + heldFor)
        await self.end(.finished(record(start: start, pauses: pauses, end: end)))
    }

    private func record(start: Instant, pauses: [Range<Instant>], end: Instant) -> WorkoutRecord<Instant> {
        WorkoutRecord(timeline: timeline, start: start, pauses: pauses, end: end)
    }

    private func end(_ progress: Snapshot.Progress) async {
        wake?.cancel()
        state = .ended
        if case .finished = progress {
            await cueRules.finish()
        } else {
            await cueRules.stop()
        }
        continuation.yield(Snapshot(progress: progress, rounds: rounds))
        continuation.finish()
    }
}
