private nonisolated let sleepTolerance = Duration.milliseconds(10)

/// Runs one Workout from one fixed start point. It publishes a snapshot only on an event, and works out
/// where the Workout is from the clock each time, so a late wake can't build up any error.
public actor WorkoutEngine<EngineClock: Clock> where EngineClock.Duration == Duration {
    public typealias Instant = EngineClock.Instant
    public typealias Snapshot = WorkoutSnapshot<Instant>

    private enum State {
        case ready
        case running(start: Instant, heldFor: Duration)
        case paused(start: Instant, heldFor: Duration, since: Instant)
        case ended
    }

    /// Ends after the snapshot for a finished or stopped Workout.
    public nonisolated let snapshots: AsyncStream<Snapshot>

    private let continuation: AsyncStream<Snapshot>.Continuation
    private let clock: EngineClock
    private let timeline: Timeline
    private let rounds: Int
    private var state = State.ready
    private var latest: Snapshot?
    private var wake: Task<Void, Never>?

    public init(workout: Workout, clock: EngineClock) {
        (snapshots, continuation) = AsyncStream.makeStream()
        self.clock = clock
        timeline = Timeline(workout: workout)
        rounds = workout.rounds
    }

    public func start() {
        guard case .ready = state else { return }
        state = .running(start: clock.now, heldFor: .zero)
        recalculate()
    }

    /// Pause keeps the time of the tap, so nothing the engine is busy with can shift the time left.
    public func pause(at tap: Instant) {
        guard case .running(let start, let heldFor) = state else { return }
        let position = timeline.position(at: start.duration(to: tap) - heldFor)
        guard let phase = position.phase else {
            end(.finished)
            return
        }
        wake?.cancel()
        state = .paused(start: start, heldFor: heldFor, since: tap)
        publish(Snapshot(progress: .paused(phase: phase, timeLeft: position.timeLeft), rounds: rounds))
    }

    /// Resume keeps the time of the tap, so the Pause's length is exactly what the owner held it for.
    public func resume(at tap: Instant) {
        guard case .paused(let start, let heldFor, let since) = state else { return }
        state = .running(start: start, heldFor: heldFor + since.duration(to: tap))
        recalculate()
    }

    public func stop() {
        switch state {
        case .ready, .running, .paused: end(.stopped)
        case .ended: break
        }
    }

    /// For returning to the front: works out where the Workout is and always publishes it, because a
    /// suspended app isn't woken by its own timer.
    public func refresh() {
        guard let snapshot = latest else { return }
        switch state {
        case .running:
            latest = nil
            recalculate()
        case .paused:
            continuation.yield(snapshot)
        case .ready, .ended:
            break
        }
    }

    /// Works out where the Workout is now. Only a change of Phase or the finish publishes anything.
    private func recalculate() {
        guard case .running(let start, let heldFor) = state else { return }
        let now = clock.now
        let position = timeline.position(at: start.duration(to: now) - heldFor)
        guard let phase = position.phase else {
            end(.finished)
            return
        }
        let endsAt = now.advanced(by: position.timeLeft)
        publish(Snapshot(progress: .running(phase: phase, endsAt: endsAt), rounds: rounds))
        wakeUp(at: endsAt)
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

    private func end(_ progress: Snapshot.Progress) {
        wake?.cancel()
        state = .ended
        continuation.yield(Snapshot(progress: progress, rounds: rounds))
        continuation.finish()
    }
}
