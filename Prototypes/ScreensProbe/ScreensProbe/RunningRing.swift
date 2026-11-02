// PROTOTYPE, throw away. The chosen running screen: each Phase has a deep tinted background and a
// lighter ring for the time left. Its colors come from the theme.
import SwiftUI

struct RunningRing: View {
    let state: ProbeState
    let runner: Runner

    private var palette: PhaseColors { state.theme.phase(runner.phase.kind) }

    var body: some View {
        VStack(spacing: 8) {
            Text(runner.phase.kind.rawValue)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ring)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(palette.track, lineWidth: 20)
                Circle()
                    .trim(from: 0, to: max(0, 1 - runner.phaseProgress))
                    .stroke(palette.ring, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(runner.timeText)
                    .font(.system(size: 132, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(10)
            Text(footerText)
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button {
                    runner.togglePause()
                } label: {
                    Label(
                        runner.isPaused ? "Resume" : "Pause",
                        systemImage: runner.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, minHeight: 72)
                }
                .buttonStyle(.glass)
                Button {
                    state.confirmStop = true
                } label: {
                    Image(systemName: "stop.fill").font(.title.bold()).frame(width: 72, height: 72)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Stop")
                .stopConfirmation(state)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
    }

    private var footerText: String {
        if runner.isPaused { return "Paused" }
        return runner.phase.round.map { "Round \($0) of \(runner.rounds)" } ?? " "
    }
}
