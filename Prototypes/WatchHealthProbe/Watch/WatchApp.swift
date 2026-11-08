// PROBE, throwaway. Two pages: the session (right) and controls with the log (left).

import HealthKit
import SwiftUI
import WatchKit

@main
struct WatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchDelegate

    var body: some Scene {
        WindowGroup {
            WatchScreen(probe: .shared)
        }
    }
}

final class WatchDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WatchProbe.shared.handle(workoutConfiguration, at: .now)
    }

    func handleActiveWorkoutRecovery() {
        WatchProbe.shared.recover()
    }
}

struct WatchScreen: View {
    @Bindable var probe: WatchProbe
    @State private var page = 1
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $page) {
            controls.tag(0)
            session.tag(1)
        }
        .tabViewStyle(.page)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await probe.refreshStatus("foreground") } }
        }
    }

    private var session: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(probe.state?.label ?? "no session")\(probe.isMirroring ? " · mirrored" : "")")
                .foregroundStyle(probe.isMirroring ? .green : .secondary)
            Text(probe.plan.map { "\($0.run)" } ?? "no plan")
                .font(.caption2)
            Text(probe.phase.map { "\($0.kind) \($0.round)" } ?? "–")
                .font(.title2.bold())
            Text(
                "♥ \(probe.heartRate.map { "\(Int($0))" } ?? "–")  (\(probe.heartRateValues)/\(probe.heartRateUpdates))"
            )
            .font(.body.monospacedDigit())
            Text(probe.healthStatus)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        List {
            Button("Ask for Health", action: probe.askForHealth)
            Button("Status") { Task { await probe.refreshStatus("button") } }
            Toggle("Ask in handle(_:)", isOn: $probe.asksInHandle)
            Button("List probe workouts", action: probe.listProbeWorkouts)
            Button("Log default types", action: probe.logDefaultCollection)
            Button("Stop (Watch)", role: .destructive, action: probe.stop)
            ForEach(Array(probe.log.lines.suffix(40).reversed().enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 10).monospaced())
            }
        }
    }
}
