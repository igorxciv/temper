import SwiftUI
import TemperCore

/// Has to hold together on the iPhone SE, 375 by 667 pt and the smallest iPhone on iOS 27, at every text size.
struct RunningScreen: View {
    let display: WorkoutRunner.Display
    let phase: Phase
    let pause: () -> Void
    let resume: () -> Void
    let stop: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = PhaseColors(kind: phase.kind, contrast: contrast)
        let snapshot = display.snapshot

        VStack(spacing: 8) {
            Text(phase.kind.name)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(colors.ring)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
            Spacer(minLength: 0)
            TimeRing(display: display, colors: colors)
                // A stroke straddles its path, so half the line's width keeps the ring inside its frame.
                .padding(10)
            RingLineView(line: display.line, colors: colors)
            Spacer(minLength: 0)
            RunningControls(isPaused: snapshot.isPaused, pause: pause, resume: resume, stop: stop)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .background(colors.background.ignoresSafeArea())
    }
}

extension Phase.Kind {
    var name: String {
        switch self {
        case .prepare: "Prepare"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }
}

/// The ring and its time. Both read the engine's clock on every display frame.
private struct TimeRing: View {
    let display: WorkoutRunner.Display
    let colors: PhaseColors

    private let lineWidth: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().stroke(colors.track, lineWidth: lineWidth)
            TimelineView(.animation(paused: display.snapshot.isPaused)) { _ in
                let ring = display.ring(at: .now)

                ZStack {
                    Circle()
                        .trim(from: 0, to: ring.fill)
                        .stroke(colors.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    // No `.numericText()` transition, because it blurred the digits.
                    Text(ring.time)
                        // Set above any phone's width, so the ring alone decides the size. From 3 m that's about
                        // 12.6 arcmin on an iPhone SE to 16.3 on the largest phone, under the 20 to 22 usually
                        // cited for reading at a distance. The owner accepted that to keep the ring's size.
                        .font(.system(size: 180, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 24)
                        // Read only when focus lands on it. The `updatesFrequently` trait would announce it as it
                        // changes, and the Cues already speak every Phase change.
                        .accessibilityLabel(ring.spokenTime)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct RingLineView: View {
    let line: RingLine?
    let colors: PhaseColors

    private let numberSize: CGFloat = 64

    var body: some View {
        Group {
            switch line {
            case .value(let value, let caption, let spoken):
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    if case .before(let text) = caption {
                        CaptionText(text: text)
                    }
                    Text(value)
                        .font(.system(size: numberSize, weight: .semibold).monospacedDigit())
                    if case .after(let text) = caption {
                        CaptionText(text: text)
                    }
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

private struct CaptionText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .medium).monospacedDigit())
            .opacity(0.72)
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
                // Asking doesn't Pause: the timer and Cues carry on while the dialog is open. If the Workout
                // finishes, the complete screen replaces this one and the dialog goes with it.
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
