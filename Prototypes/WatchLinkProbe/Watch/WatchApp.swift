// PROBE, throwaway. Three pages: the link (middle), the launch steps and counts (right), and controls (left).

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
    let probe: WatchProbe
    @State private var page = 1
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TabView(selection: $page) {
            controls.tag(0)
            link.tag(1)
            counts.tag(2)
        }
        .tabViewStyle(.page)
    }

    private var link: some View {
        VStack(spacing: 4) {
            Text("\(probe.state?.label ?? "no session")\(probe.isMirroring ? " · mirrored" : "")")
                .font(.footnote)
                .foregroundStyle(probe.isMirroring ? .green : .secondary)
            TimelineView(.periodic(from: .now, by: isLuminanceReduced ? 1 : 0.1)) { context in
                Text(probe.phaseStart.map { countdown(phaseRemaining(from: $0, at: context.date)) } ?? "–:––.–")
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
            }
            HStack {
                Text("♥ \(probe.heartRate.map { "\(Int($0))" } ?? "–")")
                Spacer()
                Text(probe.stats.lastRoundTrip.map(ms) ?? "– ms")
            }
            .font(.footnote.monospacedDigit())
            Text(probe.lastTap)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button(action: probe.tap) {
                Text("Tap")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 4)
    }

    private var counts: some View {
        List {
            ForEach(probe.steps) { step in
                LabeledContent(step.name, value: ProbeLog.time(step.at))
            }
            LabeledContent("Pings", value: "\(probe.stats.pingsSent) / \(probe.stats.pongs) back")
            LabeledContent("Send errors", value: "\(probe.stats.sendFailures)")
            LabeledContent("From iPhone", value: "\(probe.stats.pingsReceived)")
            LabeledContent("Max round trip", value: ms(probe.stats.maxRoundTrip))
            LabeledContent("iPhone ahead", value: probe.stats.best.map { ms($0.theirsAhead) } ?? "–")
        }
        .font(.caption2)
    }

    private var controls: some View {
        List {
            Button("Ask for Health", action: probe.askForHealth)
            Text(probe.healthStatus).font(.caption2)
            Button("Stop (Watch)", role: .destructive, action: probe.stop)
            Button("Stop mirroring", action: probe.stopMirroring)
            Button("Mirror again", action: probe.mirrorAgain)
            ForEach(Array(probe.log.lines.suffix(30).reversed().enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 10).monospaced())
            }
        }
    }
}
