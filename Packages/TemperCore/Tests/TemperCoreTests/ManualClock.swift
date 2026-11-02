import Synchronization

/// A clock that only moves when a test moves it, so engine tests never really sleep.
nonisolated final class ManualClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var nextID = 0
        var sleepers: [Int: Sleeper] = [:]
        var tolerances: [Duration?] = []
    }

    private let state = Mutex(State())

    let minimumResolution = Duration.nanoseconds(1)

    var now: Instant {
        state.withLock { $0.now }
    }

    /// The tolerance of every sleep so far.
    var tolerances: [Duration?] {
        state.withLock { $0.tolerances }
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = state.withLock { state in
            state.nextID += 1
            state.tolerances.append(tolerance)
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                register(id: id, deadline: deadline, continuation: continuation)
            }
        } onCancel: {
            cancel(id: id)
        }
    }

    private func register(id: Int, deadline: Instant, continuation: CheckedContinuation<Void, any Error>) {
        state.withLock { state in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            } else if deadline <= state.now {
                continuation.resume()
            } else {
                state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
            }
        }
    }

    private func cancel(id: Int) {
        let sleeper = state.withLock { $0.sleepers.removeValue(forKey: id) }
        sleeper?.continuation.resume(throwing: CancellationError())
    }

    /// Moves time forward and wakes every sleeper now due, as a single wake however far it moved.
    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let due = state.sleepers.filter { $0.value.deadline <= now }
            state.sleepers = state.sleepers.filter { $0.value.deadline > now }
            return due.values.map(\.continuation)
        }
        for continuation in due {
            continuation.resume()
        }
    }

    /// Moves time forward with no sleeper waking, as when iOS has suspended the app.
    func advanceWhileSuspended(by duration: Duration) {
        state.withLock { $0.now = $0.now.advanced(by: duration) }
    }
}
