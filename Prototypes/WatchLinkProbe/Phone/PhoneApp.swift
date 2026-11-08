// PROBE, throwaway. One screen: pick the case, Start, watch the link, end from this side, share the log.

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

    var body: some View {
        NavigationStack {
            List {
                Section("Setup") {
                    Button("Ask for Health") { probe.askForHealth() }
                    LabeledContent("Health", value: probe.healthStatus)
                    Picker("Case", selection: $probe.caseName) {
                        ForEach(PhoneProbe.cases, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Start") {
                    Button("Start (startWatchApp)") { probe.start() }
                        .font(.headline)
                    LabeledContent("Completion", value: probe.completion ?? "–")
                    LabeledContent("Mirrored after", value: probe.mirroredAfter.map(secs) ?? "–")
                    LabeledContent("State", value: probe.state?.label ?? "–")
                    LabeledContent("Instances", value: "\(probe.instances)")
                    ForEach(probe.watchSteps) { step in
                        LabeledContent("Watch: \(step.name)", value: ProbeLog.time(step.at))
                    }
                }

                Section("Link") {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        LabeledContent("Phase ends in") {
                            Text(probe.phaseStart.map { countdown(phaseRemaining(from: $0, at: context.date)) } ?? "–")
                                .font(.title.monospacedDigit().bold())
                        }
                    }
                    LabeledContent("Pings", value: "\(probe.stats.pingsSent) sent, \(probe.stats.pongs) back")
                    LabeledContent("Send errors", value: "\(probe.stats.sendFailures)")
                    LabeledContent("From Watch", value: "\(probe.stats.pingsReceived) pings")
                    LabeledContent(
                        "Round trip",
                        value: "\(probe.stats.lastRoundTrip.map(ms) ?? "–"), max \(ms(probe.stats.maxRoundTrip))")
                    LabeledContent("Watch clock ahead", value: probe.stats.best.map { ms($0.theirsAhead) } ?? "–")
                    LabeledContent(
                        "Taps", value: "\(probe.taps), last \(probe.lastTap.map(ms) ?? "–"), max \(ms(probe.maxTap))")
                    LabeledContent("Watch heart rate", value: probe.watchHeartRate.map { "\(Int($0))" } ?? "–")
                    LabeledContent("Audio", value: probe.isAudioRunning ? "running" : "stopped")
                }

                Section("End from the iPhone") {
                    Button("stopActivity(with:)") { probe.stopActivity() }
                    Button("end()", role: .destructive) { probe.end() }
                    Button("Stop audio") { probe.stopAudio() }
                    Button("Write summary to log") { probe.logSummary() }
                }

                Section("Log") {
                    ShareLink(item: probe.log.fileURL)
                    Button("Clear log", role: .destructive) { probe.log.clear() }
                    ForEach(Array(probe.log.lines.suffix(150).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                    }
                }
            }
            .navigationTitle("Link Probe")
            .onAppear { probe.refreshHealthStatus() }
        }
    }
}
