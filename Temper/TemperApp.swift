import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    @State private var runner: WorkoutRunner
    @State private var remembered = RememberedValues()

    init() {
        let health = HealthSaves()
        health.retryWhenPossible()
        let runner = WorkoutRunner(health: health)
        _runner = State(initialValue: runner)
        // The Live Activity's Pause, Resume and Done run in this process, and may be what launched it, so the
        // runner is set before any of them can run.
        LiveActivityControls.workout = runner
    }

    var body: some Scene {
        WindowGroup {
            RootView(runner: runner, remembered: remembered)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
///
/// The running and complete screens replace the whole navigation stack, so nothing on screen distracts from the time.
/// The stack's path lives in `RememberedValues`, so leaving a Workout comes back to the Plan it started from.
struct RootView: View {
    let runner: WorkoutRunner
    @Bindable var remembered: RememberedValues

    /// The board of the Plan the Workout was started from, for the complete screen to tick off, or `nil` for a Workout
    /// started elsewhere, as by a debug launch.
    @State private var ranBoard: PlanBoard?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let snapshot = runner.snapshot {
                let display = RunningDisplay(workout: runner.workout, snapshot: snapshot)
                if let phase = snapshot.phase {
                    RunningScreen(
                        display: display,
                        phase: phase,
                        pause: runner.pause,
                        resume: runner.resume,
                        done: runner.done,
                        stop: runner.stop
                    )
                } else {
                    // The runner keeps only an ended snapshot with a complete screen.
                    switch display.completion {
                    case .rounds(let summary):
                        RoundsCompleteScreen(
                            summary: summary, activeTime: snapshot.record?.activeTime ?? .zero,
                            health: runner.health, close: close)
                    case .total(let total):
                        CompleteScreen(board: ranBoard, total: total, health: runner.health, close: close)
                    case nil:
                        EmptyView()
                    }
                }
            } else {
                NavigationStack(path: $remembered.path) {
                    PlansScreen(remembered: remembered)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .plan(let workoutType):
                                PlanScreen(workoutType: workoutType, remembered: remembered) { workoutType, workout in
                                    ranBoard = PlanBoard(workoutType: workoutType, settings: remembered[workoutType])
                                    runner.start(
                                        workout, filedAs: HealthRecord.ActivityType(workoutType),
                                        isDipOn: remembered.isDipOn)
                                }
                            case .describe:
                                DescribeScreen(remembered: remembered) { workout, activityType in
                                    ranBoard = remembered.describedPlan.map(PlanBoard.init(plan:))
                                    runner.start(workout, filedAs: activityType, isDipOn: remembered.isDipOn)
                                }
                            case .settings:
                                SettingsScreen(remembered: remembered, health: runner.health)
                            }
                        }
                }
                .tint(BoardInk(contrast: contrast).marker)
            }
        }
        .fontDesign(.rounded)
        #if DEBUG
            .task {
                if let board = DebugLaunch.apply(runner: runner, remembered: remembered) {
                    ranBoard = board
                }
            }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                runner.refresh()
            }
        }
    }

    private func close() {
        ranBoard = nil
        runner.finish()
    }
}
