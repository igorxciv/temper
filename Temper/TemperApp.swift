import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    @State private var runner = WorkoutRunner()
    @State private var remembered = RememberedValues()

    var body: some Scene {
        WindowGroup {
            RootView(runner: runner, remembered: remembered)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
struct RootView: View {
    let runner: WorkoutRunner
    let remembered: RememberedValues

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast

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
                    CompleteScreen(total: runner.total, done: runner.finish)
                }
            } else {
                NavigationStack {
                    SetupScreen(remembered: remembered, start: runner.start)
                }
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
