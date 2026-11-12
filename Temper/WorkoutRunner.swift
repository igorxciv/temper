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
    /// Opens the Watch at each Start and keeps it in step with the Workout.
    @ObservationIgnored private let watch: WatchLink

    /// Saves each ended Workout to Health, and asks for permission from Settings.
    let health: HealthSaves
    /// The UUID of the Workout last started, made at Start, until its Health save begins.
    @ObservationIgnored private var healthWorkoutID: UUID?
    /// The running Workout's fixed start point as a wall-clock date, or `nil` until the engine sets it. A Watch
    /// session that starts at or after it belongs to the running Workout.
    @ObservationIgnored private(set) var startDate: Date?

    #if DEBUG
        @ObservationIgnored private var timingLog: TimingLog?
    #endif

    /// Rendering begins here, at launch, so the Cues are usually ready before the first Start. The Watch link is made
    /// here too, because HealthKit may launch the app in the background to hand over the Watch's session.
    init(health: HealthSaves = HealthSaves(), watch: WatchLink = WatchLink()) {
        self.health = health
        self.watch = watch
        cues.render()
        watch.tapped = { [weak self] command, tap in self?.apply(command, at: tap) }
        Task { await LiveActivityAdapter.endLeftovers() }
    }

    func start(_ workout: Workout, of workoutType: WorkoutType, isDipOn: Bool) {
        guard engine == nil else { return }
        self.workout = workout
        self.workoutType = workoutType
        let workoutID = UUID()
        healthWorkoutID = workoutID
        startDate = nil
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
            health.timingLog = audio.timingLog
            timingLog?.write("dip", ["dip": isDipOn])
        #endif
        Task { [cues] in
            await cues.waitForRendering(atMost: renderingWaitLimit)
            if let start = await engine.start() {
                let startDate = ClockAnchor.now.date(of: start)
                self.startDate = startDate
                // Opened only once the start point is set, so the Watch's session always starts after it and is
                // matched to this Workout.
                watch.start(workoutID: workoutID, workoutType: workoutType, start: startDate)
            }
            for await snapshot in engine.snapshots {
                show(snapshot)
            }
        }
    }

    func pause() {
        apply(.pause, at: .now)
    }

    func resume() {
        apply(.resume, at: .now)
    }

    /// Ends the open Work at the tap. The engine ignores it outside a running open Work.
    func done() {
        apply(.done, at: .now)
    }

    func stop() {
        apply(.stop, at: .now)
    }

    /// Hands a tap to the engine at `tap`: now for the screen and the Live Activity, or a little earlier for the
    /// Watch, whose link placed it back by its trip. The engine clamps either one after what it last applied.
    private func apply(_ command: WatchCommand, at tap: ContinuousClock.Instant) {
        Task { [engine] in
            switch command {
            case .pause: await engine?.pause(at: tap)
            case .resume: await engine?.resume(at: tap)
            case .done: await engine?.done(at: tap)
            case .stop: await engine?.stop(at: tap)
            }
        }
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
        saveToHealth(snapshot)
        let display = Display(workout: workout, snapshot: snapshot)
        // Before an ended Workout returns to setup, so the Watch hears that it ended.
        watch.show(display.watchState(at: .now, date: .now))
        // An ended Workout with no complete screen, as after a Stop in Intervals and Stopwatch, returns to setup.
        if snapshot.phase == nil, display.completion == nil {
            finish()
            return
        }
        self.snapshot = snapshot
        liveActivity?.show(display.liveActivityState(at: .now, date: .now))
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

// MARK: - Health

extension WorkoutRunner {
    /// Builds the Workout's Health record and hands it to Health the first time an ended snapshot arrives, before the
    /// screens let go of anything, so the save's background task begins while the app is surely running. The record
    /// is `nil` for a Workout too short to save.
    ///
    /// The Watch gets the same record in `end`, before it hears the Workout ended, and saves it with heart rate. Both
    /// copies carry identical times, and Health keeps the Watch's in place of this one.
    fileprivate func saveToHealth(_ snapshot: Snapshot) {
        guard let record = snapshot.record, let workoutID = healthWorkoutID.take() else { return }
        let healthRecord = HealthRecord(record, of: workoutType, workoutID: workoutID, attempt: 1, anchor: .now)
        watch.hold(healthRecord)
        health.save(healthRecord)
    }
}

extension WorkoutRunner: WorkoutControls {}
