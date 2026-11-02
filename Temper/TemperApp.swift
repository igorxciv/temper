import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    /// The Workout every run uses until setup arrives.
    static let fixedWorkout = WorkoutSettings.firstLaunch.makeWorkout()

    @State private var runner = WorkoutRunner(workout: Self.fixedWorkout)

    var body: some Scene {
        WindowGroup {
            RootView(runner: runner)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
struct RootView: View {
    let runner: WorkoutRunner

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let snapshot = runner.snapshot {
                if let phase = snapshot.phase {
                    RunningScreen(
                        snapshot: snapshot,
                        phase: phase,
                        pause: runner.pause,
                        resume: runner.resume,
                        stop: runner.stop
                    )
                } else {
                    CompleteScreen(total: runner.workout.totalDuration, done: runner.finish)
                }
            } else {
                StartScreen(total: runner.workout.totalDuration, start: runner.start)
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
