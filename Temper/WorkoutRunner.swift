import Observation
import TemperCore
import UIKit

/// Connects the screens to the Workout engine: it reads the clock at each tap and holds the latest
/// snapshot. It makes no timing decisions of its own.
@Observable
final class WorkoutRunner {
    typealias Snapshot = WorkoutSnapshot<ContinuousClock.Instant>

    let workout: Workout

    /// The latest snapshot, or `nil` when no Workout is running or complete.
    private(set) var snapshot: Snapshot? {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = snapshot?.keepsScreenAwake ?? false
        }
    }

    @ObservationIgnored private var engine: WorkoutEngine<ContinuousClock>?

    init(workout: Workout) {
        self.workout = workout
    }

    func start() {
        guard engine == nil else { return }
        let engine = WorkoutEngine(workout: workout, clock: ContinuousClock())
        self.engine = engine
        Task {
            await engine.start()
            for await snapshot in engine.snapshots {
                show(snapshot)
            }
        }
    }

    func pause() {
        let tap = ContinuousClock.now
        Task { [engine] in await engine?.pause(at: tap) }
    }

    func resume() {
        let tap = ContinuousClock.now
        Task { [engine] in await engine?.resume(at: tap) }
    }

    func stop() {
        Task { [engine] in await engine?.stop() }
    }

    /// For returning to the front, so the screen shows the correct Phase or the complete screen.
    func refresh() {
        Task { [engine] in await engine?.refresh() }
    }

    /// Leaves the complete screen.
    func finish() {
        engine = nil
        snapshot = nil
    }

    private func show(_ snapshot: Snapshot) {
        if case .stopped = snapshot.progress {
            finish()
        } else {
            self.snapshot = snapshot
        }
    }
}
