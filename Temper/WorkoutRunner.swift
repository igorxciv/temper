import Observation
import TemperCore
import UIKit

/// How long Start waits for Cues still rendering. Rendering took under 2s on a real iPhone.
private let renderingWaitLimit = Duration.seconds(5)

/// Connects the screens to the Workout engine: it reads the clock at each tap and holds the latest
/// snapshot. It makes no timing decisions of its own.
@Observable
final class WorkoutRunner {
    typealias Snapshot = WorkoutSnapshot<ContinuousClock.Instant>
    typealias Display = RunningDisplay<ContinuousClock.Instant>

    /// The Workout last started.
    private(set) var workout = Workout(phases: [])
    /// The Workout Type of the Workout last started, which decides how the running screen shows it.
    private(set) var workoutType = WorkoutType.intervals

    /// The latest snapshot, or `nil` when no Workout is running or complete.
    private(set) var snapshot: Snapshot? {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = snapshot?.keepsScreenAwake ?? false
        }
    }

    @ObservationIgnored private var engine: WorkoutEngine<ContinuousClock>?
    @ObservationIgnored private let cues = CueBank()
    @ObservationIgnored private var liveActivity: LiveActivityAdapter?

    #if DEBUG
        @ObservationIgnored private var timingLog: TimingLog?
    #endif

    /// Rendering begins here, at launch, so the Cues are usually ready before the first Start.
    init() {
        cues.render()
        Task { await LiveActivityAdapter.endLeftovers() }
    }

    func start(_ workout: Workout, of workoutType: WorkoutType, isDipOn: Bool) {
        guard engine == nil else { return }
        self.workout = workout
        self.workoutType = workoutType
        let audio = AudioAdapter(cues: cues, application: .shared)
        let engine = WorkoutEngine(
            workout: workout,
            clock: ContinuousClock(),
            audio: audio,
            isDipOn: isDipOn
        )
        self.engine = engine
        liveActivity = LiveActivityAdapter()
        #if DEBUG
            timingLog = audio.timingLog
            timingLog?.write("dip", ["dip": isDipOn])
        #endif
        Task { [cues] in
            await cues.waitForRendering(atMost: renderingWaitLimit)
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
        let tap = ContinuousClock.now
        Task { [engine] in await engine?.stop(at: tap) }
    }

    /// For returning to the front, so the screen shows the correct Phase or the complete screen.
    func refresh() {
        Task { [engine] in await engine?.refresh() }
    }

    /// Leaves the complete screen.
    func finish() {
        engine = nil
        snapshot = nil
        liveActivity?.show(nil)
        liveActivity = nil
    }

    private func show(_ snapshot: Snapshot) {
        #if DEBUG
            logTiming(of: snapshot)
        #endif
        if case .stopped = snapshot.progress {
            finish()
        } else {
            self.snapshot = snapshot
            let display = Display(workoutType: workoutType, workout: workout, snapshot: snapshot)
            liveActivity?.show(display.liveActivityState(at: .now, date: .now))
        }
    }

    #if DEBUG
        /// A Phase's end is timed where the screen learns of it, so the figure covers everything before the screen.
        private func logTiming(of next: Snapshot) {
            switch next.progress {
            case .paused, .pausedOpen:
                return
            case .stopped:
                timingLog?.write("run_end", ["completed": false])
                return
            case .running, .runningOpen, .finished:
                break
            }
            if case .running(let phase, let endsAt) = snapshot?.progress, phase != next.phase {
                let late = endsAt.duration(to: .now) / .milliseconds(1)
                let nextPhase = next.phase.map { "\($0.kind)" } ?? "finished"
                timingLog?.write("phase_end", ["late_ms": late, "next": nextPhase])
            }
            if case .finished = next.progress {
                timingLog?.write("run_end", ["completed": true])
            }
        }
    #endif
}

extension WorkoutRunner: WorkoutControls {}
