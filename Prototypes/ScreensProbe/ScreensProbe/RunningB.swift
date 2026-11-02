// PROTOTYPE, throw away. Running B: follows light and dark appearance. A ring shows the current Phase,
// a strip shows the whole Workout, and the next Phase is always named.
import SwiftUI

struct RunningB: View {
    let state: ProbeState
    let runner: Runner

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 2) {
                ForEach(runner.phases.indices, id: \.self) { index in
                    (index <= runner.index
                        ? runner.phases[index].kind.fill : Color.secondary.opacity(0.25))
                        .frame(height: index == runner.index ? 14 : 8)
                        .clipShape(.capsule)
                }
            }
            .frame(height: 14)
            .padding(.top, 8)
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 26)
                Circle()
                    .trim(from: 0, to: 1 - runner.phaseProgress)
                    .stroke(
                        runner.phase.kind.fill, style: StrokeStyle(lineWidth: 26, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(runner.isPaused ? "Paused" : runner.phase.kind.rawValue)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(runner.timeText)
                        .font(.system(size: 96, weight: .heavy, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let round = runner.phase.round {
                        Text("Round \(round) of \(runner.rounds)")
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(28)
            }
            .padding(13)
            Text(nextText)
                .font(.title2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            GlassEffectContainer {
                HStack(spacing: 28) {
                    Button {
                        state.confirmStop = true
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.iconOnly)
                            .font(.title.bold())
                            .frame(width: 64, height: 64)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .stopConfirmation(state)
                    Button {
                        runner.togglePause()
                    } label: {
                        Label(
                            runner.isPaused ? "Resume" : "Pause",
                            systemImage: runner.isPaused ? "play.fill" : "pause.fill"
                        )
                        .labelStyle(.iconOnly)
                        .font(.largeTitle.bold())
                        .frame(width: 88, height: 88)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    private var nextText: String {
        guard let next = runner.next else { return "Last Phase" }
        return "Next: \(next.kind.rawValue) \(clock(next.seconds))"
    }
}
