// PROBE, throwaway. One screen: Health status, pick the run, Start, Pause, Stop, list probe workouts, share the log.

import HealthKit
import SwiftUI

@main
struct PhoneApp: App {
    @State private var probe = PhoneProbe()

    var body: some Scene {
        WindowGroup {
            PhoneScreen(probe: probe)
        }
    }
}

struct PhoneScreen: View {
    @Bindable var probe: PhoneProbe
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Health") {
                    Button("Ask for Health") { probe.askForHealth() }
                    Button("Status") { Task { await probe.refreshStatus("button") } }
                    Text(probe.healthStatus).font(.caption)
                }

                Section("Run") {
                    Picker("Run", selection: $probe.run) {
                        ForEach(PhoneProbe.Run.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Button("Start (startWatchApp)") { probe.start() }
                        .font(.headline)
                    LabeledContent("Completion", value: probe.completion ?? "–")
                    LabeledContent("Mirrored after", value: probe.mirroredAfter.map(secs) ?? "–")
                    LabeledContent("State", value: probe.state?.label ?? "–")
                    LabeledContent("Phase", value: probe.phase.map { "\($0.kind) \($0.round)" } ?? "–")
                    LabeledContent(
                        "Watch heart rate",
                        value: "\(probe.watchHeartRate.map { "\(Int($0))" } ?? "–") (\(probe.watchUpdates) updates)")
                }

                Section("Control") {
                    Button(probe.isPaused ? "Resume" : "Pause") {
                        probe.isPaused ? probe.resume() : probe.pause()
                    }
                    Button("Stop (Watch saves)") { probe.stop() }
                    Button("Force stopActivity(with:)", role: .destructive) { probe.forceStop() }
                    Button("Stop audio") { probe.stopAudio() }
                }

                Section("Check") {
                    Button("List probe workouts") { probe.listProbeWorkouts() }
                }

                Section("Log") {
                    ShareLink(item: probe.log.fileURL)
                    Button("Clear log", role: .destructive) { probe.log.clear() }
                    ForEach(Array(probe.log.lines.suffix(200).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                    }
                }
            }
            .navigationTitle("Health Probe")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await probe.refreshStatus("foreground") } }
            }
        }
    }
}
