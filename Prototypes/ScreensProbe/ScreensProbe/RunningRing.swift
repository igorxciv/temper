// PROTOTYPE, throw away. The chosen running screen: each Phase has a deep tinted background and a
// lighter ring for the time left. Rounds are drawn by the style chosen in the probe bar.
import SwiftUI

struct RunningRing: View {
    let state: ProbeState
    let runner: Runner

    private var palette: PhaseColors { state.theme.phase(runner.phase.kind) }
    private var style: RoundStyle { state.roundStyle }

    var body: some View {
        VStack(spacing: 8) {
            Text(runner.phase.kind.rawValue)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ring)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
            Spacer(minLength: 0)
            ring
            if style != .bezel {
                RoundCount(runner: runner, usesOxide: style == .temper)
                mark
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
            }
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

    private var ring: some View {
        let width: CGFloat = style == .bezel ? 14 : 20
        return ZStack {
            if style == .bezel {
                RoundDial(
                    count: runner.rounds, filled: runner.roundsFilled,
                    done: state.theme.colors.accent, current: palette.ring, future: palette.track
                )
            }
            ZStack {
                Circle().stroke(palette.track, lineWidth: width)
                Circle()
                    .trim(from: 0, to: max(0, 1 - runner.phaseProgress))
                    .stroke(palette.ring, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(runner.timeText)
                    .font(.system(size: 132, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)
                if style == .bezel {
                    VStack {
                        Spacer()
                        RoundCount(runner: runner, size: 44)
                    }
                    .padding(.bottom, 34)
                }
            }
            .padding(style == .bezel ? 25 : 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var mark: some View {
        if style == .temper {
            TemperBar(
                count: runner.rounds, filled: runner.roundsFilled, track: palette.track,
                cut: palette.background
            )
        } else {
            ChalkTally(
                count: runner.rounds, filled: runner.roundsFilled, done: palette.text,
                current: palette.ring, future: palette.track, surface: palette.background
            )
            .frame(height: 58)
        }
    }
}
