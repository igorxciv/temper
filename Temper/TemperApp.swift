import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    @State private var runner: WorkoutRunner
    @State private var remembered = RememberedValues()

    init() {
        let runner = WorkoutRunner()
        _runner = State(initialValue: runner)
        // The Live Activity's Pause and Resume run in this process, and may be what launched it, so the runner
        // is set before any of them can run.
        LiveActivityControls.workout = runner
    }

    var body: some Scene {
        WindowGroup {
            RootView(runner: runner, remembered: remembered)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
struct RootView: View {
    let runner: WorkoutRunner
    @Bindable var remembered: RememberedValues

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let snapshot = runner.snapshot {
                if let phase = snapshot.phase {
                    RunningScreen(
                        display: RunningDisplay(
                            workoutType: runner.workoutType,
                            workout: runner.workout,
                            snapshot: snapshot
                        ),
                        phase: phase,
                        pause: runner.pause,
                        resume: runner.resume,
                        stop: runner.stop
                    )
                } else {
                    CompleteScreen(total: runner.workout.totalDuration, done: runner.finish)
                }
            } else {
                // The system Liquid Glass tab bar, with no background of its own.
                TabView(selection: $remembered.selectedTab) {
                    ForEach(WorkoutType.allCases) { workoutType in
                        Tab(
                            workoutType.title, systemImage: workoutType.systemImage,
                            value: RootTab.workoutType(workoutType)
                        ) {
                            NavigationStack {
                                SetupScreen(workoutType: workoutType, remembered: remembered) { workoutType, workout in
                                    runner.start(workout, of: workoutType, isDipOn: remembered.isDipOn)
                                }
                            }
                        }
                    }
                    Tab("Settings", systemImage: "gearshape", value: RootTab.settings) {
                        NavigationStack {
                            SettingsScreen(remembered: remembered)
                        }
                    }
                }
                // Dragging the setup rows scrolls, and the tabs stay in view through it.
                .tabBarMinimizeBehavior(.never)
                .tint(InkColors(contrast: contrast).accent)
            }
        }
        .fontDesign(.rounded)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                runner.refresh()
            }
        }
    }
}
