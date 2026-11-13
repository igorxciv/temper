import SwiftUI
import TemperCore

/// Has to hold together on the iPhone SE, 375 by 667 pt and the smallest iPhone on iOS 27, at every text size.
struct RunningScreen: View {
    let display: WorkoutRunner.Display
    let phase: Phase
    let pause: () -> Void
    let resume: () -> Void
    let done: () -> Void
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
            RunningControls(
                isPaused: snapshot.isPaused,
                doneButton: display.doneButton,
                pause: pause,
                resume: resume,
                done: done,
                stop: stop
            )
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .background(colors.background.ignoresSafeArea())
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
                        // With Done, low enough for "72:15" in the smaller ring it leaves on an iPhone SE.
                        .minimumScaleFactor(display.doneButton == nil ? 0.4 : 0.3)
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

    /// Smaller than the time by a wide margin, so the line reads as a note on the ring and never as a second clock.
    private let numberSize: CGFloat = 48

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
                    .font(.system(size: 40, weight: .semibold))
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
            .font(.system(size: 28, weight: .medium).monospacedDigit())
            .opacity(0.72)
    }
}

/// Pause or Resume, and Stop, with Done above them in Open Rounds and Stopwatch. The Phase name, ring and line above give up height
/// to Done, so the ring shrinks to make room for it.
private struct RunningControls: View {
    let isPaused: Bool
    let doneButton: WorkoutRunner.Display.DoneButton?
    let pause: () -> Void
    let resume: () -> Void
    let done: () -> Void
    let stop: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                if let doneButton {
                    DoneControl(isEnabled: doneButton == .enabled, done: done)
                }
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
                    .confirmationDialog(
                        "End this Workout?", isPresented: $isConfirmingStop, titleVisibility: .visible
                    ) {
                        Button("End Workout", role: .destructive, action: stop)
                        Button("Keep Going", role: .cancel) {}
                    }
                }
            }
        }
        // The time is the point of this screen, so the buttons can't grow into it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Done, in Work's ring color, for Open Rounds' open Work and a Stopwatch's Work past its set length. No tap-anywhere,
/// because a phone on a bench can be brushed. Until the engine would take it, its place is held empty, so Pause, Stop
/// and the ring never move, and a control that can't be used doesn't sit in the thumb's way.
private struct DoneControl: View {
    let isEnabled: Bool
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var taps = 0

    private let height: CGFloat = 88

    var body: some View {
        let work = PhaseColors(kind: .work, contrast: contrast)

        ZStack {
            if isEnabled {
                Button {
                    taps += 1
                    done()
                } label: {
                    Text("Done")
                        .font(.title.bold())
                        // Dark on Work's ring color.
                        .foregroundStyle(work.background)
                        .frame(maxWidth: .infinity, minHeight: height)
                }
                .buttonStyle(.glassProminent)
                .tint(work.ring)
                .accessibilityShowsLargeContentViewer()
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .animation(.easeOut(duration: 0.25), value: isEnabled)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
