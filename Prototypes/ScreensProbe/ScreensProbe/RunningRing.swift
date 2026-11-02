// PROTOTYPE, throw away. The chosen running screen: each Phase has a deep tinted background and a
// lighter ring for the time left, with the Round number below. The Temper bar that once sat under
// it is in this branch's history at 8617a1c.
import SwiftUI

struct RunningRing: View {
    let state: ProbeState
    let runner: Runner

    private var palette: PhaseColors { state.theme.phase(runner.phase.kind) }
    private var style: TimeStyle { state.timeStyle }

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
                Circle().stroke(palette.track, lineWidth: style.ringWidth)
                Circle()
                    .trim(from: 0, to: max(0, 1 - runner.phaseProgress))
                    .stroke(
                        palette.ring,
                        style: StrokeStyle(lineWidth: style.ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(runner.timeText)
                    // Set above any phone's width, so the ring alone decides the size.
                    .font(.system(size: 180, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, style.digitPadding)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(style.ringPadding)
            RoundCount(runner: runner)
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
            // The time is the point of this screen, so the buttons can't grow into it. Their words
            // stop growing at the largest standard size, and a long press shows them enlarged.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
        }
        .padding(.horizontal, style.screenPadding)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
    }
}

/// The Round number, set large enough to read from across a room, with the total beside it.
private struct RoundCount: View {
    let runner: Runner
    var size: CGFloat = 64

    var body: some View {
        Group {
            if runner.isPaused {
                Text("Paused").font(.system(size: size * 0.66, weight: .semibold, design: .rounded))
            } else if runner.phase.kind == .prepare {
                pair("\(runner.rounds)", runner.rounds == 1 ? "Round" : "Rounds")
            } else {
                pair("\(runner.phase.round ?? runner.rounds)", "of \(runner.rounds)")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(height: size * 1.15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func pair(_ big: String, _ small: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.14) {
            Text(big)
                .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
            Text(small)
                .font(
                    .system(size: size * 0.5, weight: .medium, design: .rounded).monospacedDigit()
                )
                .opacity(0.72)
        }
    }

    private var label: String {
        if runner.isPaused { return "Paused" }
        if let round = runner.phase.round { return "Round \(round) of \(runner.rounds)" }
        return runner.rounds == 1 ? "1 Round" : "\(runner.rounds) Rounds"
    }
}
