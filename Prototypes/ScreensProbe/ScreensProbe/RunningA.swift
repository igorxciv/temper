// PROTOTYPE, throw away. Running A: the whole screen takes the Phase's color, so the Phase reads
// from across the room. Time left dominates, and Pause and Stop are large bottom buttons.
import SwiftUI

struct RunningA: View {
    let state: ProbeState
    let runner: Runner

    private var kind: PhaseKind { runner.phase.kind }
    private var ink: Color { runner.isPaused ? .white : kind.onFill }

    var body: some View {
        VStack(spacing: 0) {
            Text(roundText)
                .font(.title.bold().monospacedDigit())
                .padding(.top, 12)
            Spacer()
            Text(kind.rawValue.uppercased())
                .font(.system(size: 64, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(runner.timeText)
                .font(.system(size: 170, weight: .heavy, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Spacer()
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
        .foregroundStyle(ink)
        .background((runner.isPaused ? Color(white: 0.25) : kind.fill).ignoresSafeArea())
    }

    private var roundText: String {
        if runner.isPaused { return "PAUSED" }
        return runner.phase.round.map { "ROUND \($0) OF \(runner.rounds)" } ?? " "
    }
}
