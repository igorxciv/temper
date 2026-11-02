// PROTOTYPE, throw away. Running C: no visible controls. The time fills the screen, and a tap anywhere
// is Pause, so a sweaty hand needs no aim. Stop is only reachable from the paused state.
// Monochrome: Work is black, Rest is inverted white.
import SwiftUI

struct RunningC: View {
    let state: ProbeState
    let runner: Runner

    private var background: Color {
        switch runner.phase.kind {
        case .work: .black
        case .rest: .white
        case .prepare, .cooldown: Color(white: 0.22)
        }
    }

    private var ink: Color { runner.phase.kind == .rest ? .black : .white }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(runner.phase.kind.rawValue.uppercased())
                    .font(.system(size: 54, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Text(bigTime)
                    .font(.system(size: 400, weight: .black, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .frame(maxWidth: .infinity)
                Spacer()
                roundMarks
            }
            .padding()
            .foregroundStyle(ink)
            .background(background.ignoresSafeArea())
            .contentShape(.rect)
            .onTapGesture { runner.togglePause() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Pause")

            if runner.isPaused { pausedOverlay }
        }
    }

    /// Under a minute the colon and leading zero go, so the digits can be as big as possible.
    private var bigTime: String {
        let seconds = Int(runner.remaining.rounded(.up))
        return seconds < 60 ? "\(seconds)" : clock(seconds)
    }

    @ViewBuilder
    private var roundMarks: some View {
        if let round = runner.phase.round {
            if runner.rounds <= 16 {
                HStack(spacing: 6) {
                    ForEach(1...runner.rounds, id: \.self) { index in
                        Capsule()
                            .fill(index <= round ? ink : ink.opacity(0.25))
                            .frame(height: 16)
                    }
                }
            } else {
                Text("\(round) / \(runner.rounds)").font(.largeTitle.bold().monospacedDigit())
            }
        } else {
            Color.clear.frame(height: 16)
        }
    }

    private var pausedOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Paused · \(runner.timeText)").font(.largeTitle.bold().monospacedDigit())
            Button {
                runner.togglePause()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, minHeight: 110)
            }
            .buttonStyle(.glassProminent)
            Button {
                state.confirmStop = true
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.glass)
            .stopConfirmation(state)
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }
}
