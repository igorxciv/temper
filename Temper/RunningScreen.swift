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
            PhaseTime(display: display, colors: colors)
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
        // The board is light, and a running Workout is its dark Phase field, status bar and controls included.
        .preferredColorScheme(.dark)
    }
}

/// The time, as large as the width allows, and the Phase's progress in a thin bar under it. Both read the engine's
/// clock on every display frame.
private struct PhaseTime: View {
    let display: WorkoutRunner.Display
    let colors: PhaseColors

    var body: some View {
        TimelineView(.animation(paused: display.snapshot.isPaused)) { _ in
            let ring = display.ring(at: .now)

            VStack(spacing: 0) {
                // No `.numericText()` transition, because it blurred the digits.
                Text(ring.shortTime)
                    // Set above any phone's width, so the width alone decides the size. From 3 m that's roughly 20
                    // arcmin for a time under ten minutes, as 0:08, on an iPhone SE and 25 on the largest phone, and
                    // 16 to 20 for a longer one, as 12:30, against the 20 to 22 usually cited for reading at a
                    // distance.
                    .font(.system(size: 200, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
                    // Low enough for "72:15" on an iPhone SE, with Done taking height under it.
                    .minimumScaleFactor(0.3)
                    // Read only when focus lands on it. The `updatesFrequently` trait would announce it as it
                    // changes, and the Cues already speak every Phase change.
                    .accessibilityLabel(ring.spokenTime)
                PhaseBar(fill: ring.fill, colors: colors)
            }
        }
    }
}

/// A thin bar of the Phase's progress, as on the Watch. An open Phase shows only the track.
private struct PhaseBar: View {
    let fill: Double
    let colors: PhaseColors

    private let height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(colors.track)
                if fill > 0 {
                    Capsule()
                        .fill(colors.ring)
                        .frame(width: max(proxy.size.width * fill, height))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
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
        // Paused is shorter than a count, and swapping them mustn't move the time.
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

/// Pause or Resume, and Stop, with Done above them in Open Rounds and Stopwatch. The Phase name, time and line above
/// give up height to Done.
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
/// because a phone on a bench can be brushed. Disabled, it
/// stays in place and dims, and VoiceOver reads it as dimmed.
private struct DoneControl: View {
    let isEnabled: Bool
    let done: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var taps = 0

    var body: some View {
        let work = PhaseColors(kind: .work, contrast: contrast)

        Button {
            taps += 1
            done()
        } label: {
            Text("Done")
                .font(.title.bold())
                // Dark on Work's ring color, and the system's dimmed style once disabled takes the tint away.
                .foregroundStyle(isEnabled ? AnyShapeStyle(work.background) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.glassProminent)
        .tint(work.ring)
        .disabled(!isEnabled)
        .accessibilityShowsLargeContentViewer()
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
