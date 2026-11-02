import SwiftUI
import TemperCore

struct RunningScreen: View {
    let snapshot: WorkoutRunner.Snapshot
    let phase: Phase
    let pause: () -> Void
    let resume: () -> Void
    let stop: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = PhaseColors(kind: phase.kind, contrast: contrast)

        VStack(spacing: 8) {
            Text(phase.kind.name)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(colors.ring)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
            Spacer(minLength: 0)
            TimeRing(snapshot: snapshot, colors: colors)
                .padding(10)
            RoundLineView(line: snapshot.roundLine, colors: colors)
            Spacer(minLength: 0)
            RunningControls(isPaused: snapshot.isPaused, pause: pause, resume: resume, stop: stop)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .background(colors.background.ignoresSafeArea())
    }
}

extension Phase.Kind {
    fileprivate var name: String {
        switch self {
        case .prepare: "Prepare"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }
}

/// The ring and the time left. Both read the engine's clock on every display frame.
private struct TimeRing: View {
    let snapshot: WorkoutRunner.Snapshot
    let colors: PhaseColors

    private let lineWidth: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().stroke(colors.track, lineWidth: lineWidth)
            TimelineView(.animation(paused: snapshot.isPaused)) { _ in
                let now = ContinuousClock.now

                ZStack {
                    Circle()
                        .trim(from: 0, to: snapshot.fractionLeft(at: now))
                        .stroke(colors.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(snapshot.timeLeft(at: now).clockText)
                        // Set above any phone's width, so the ring alone decides the size.
                        .font(.system(size: 180, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 24)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct RoundLineView: View {
    let line: RoundLine?
    let colors: PhaseColors

    private let numberSize: CGFloat = 64

    var body: some View {
        Group {
            switch line {
            case .count(let number, let caption, let spoken):
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(number)")
                        .font(.system(size: numberSize, weight: .semibold).monospacedDigit())
                    Text(caption)
                        .font(.system(size: 32, weight: .medium).monospacedDigit())
                        .opacity(0.72)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
            case .paused:
                Text("Paused")
                    .font(.system(size: 42, weight: .semibold))
            case nil:
                EmptyView()
            }
        }
        .foregroundStyle(colors.text)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        // Paused is shorter than a count, and swapping them mustn't move the ring.
        .frame(height: numberSize * 1.15)
    }
}

private struct RunningControls: View {
    let isPaused: Bool
    let pause: () -> Void
    let resume: () -> Void
    let stop: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button(action: isPaused ? resume : pause) {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
                .buttonStyle(.glass)
                .accessibilityShowsLargeContentViewer()

                Button {
                    isConfirmingStop = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title.bold())
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Stop")
                .confirmationDialog("End this Workout?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
                    Button("End Workout", role: .destructive, action: stop)
                    Button("Keep Going", role: .cancel) {}
                }
            }
        }
        // The time is the point of this screen, so the buttons can't grow into it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
