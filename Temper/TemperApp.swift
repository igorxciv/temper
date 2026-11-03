import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    @State private var runner = WorkoutRunner()
    @State private var remembered = RememberedValues()
    @State private var probe = ProbeState()

    var body: some Scene {
        WindowGroup {
            RootView(runner: runner, remembered: remembered, probe: probe)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
struct RootView: View {
    let runner: WorkoutRunner
    let remembered: RememberedValues
    let probe: ProbeState

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let snapshot = runner.snapshot {
                if let phase = snapshot.phase {
                    RunningScreen(
                        snapshot: snapshot,
                        phase: phase,
                        type: probe.runningType,
                        stopwatchLength: probe.stopwatch.work,
                        stopwatchLine: probe.line,
                        pause: runner.pause,
                        resume: runner.resume,
                        stop: runner.stop
                    )
                    .probeBar(probe)
                } else {
                    CompleteScreen(total: runner.total, done: runner.finish)
                        .probeBar(probe)
                }
            } else {
                ProbeHome(probe: probe, remembered: remembered) { type, workout in
                    probe.type = type
                    probe.runningType = type
                    runner.start(workout, isDipOn: remembered.isDipOn)
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
