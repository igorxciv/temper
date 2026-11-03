import SwiftUI
import TemperCore

/// Has to hold together on the iPhone SE, 375 by 667 pt and the smallest iPhone on iOS 27, at every text size.
struct RunningScreen: View {
    let snapshot: WorkoutRunner.Snapshot
    let phase: Phase
    /// PROTOTYPE: a Stopwatch's Work counts up, and its line under the ring replaces the Round line.
    let type: WorkoutType
    let stopwatchLength: Duration
    let stopwatchLine: StopwatchLine
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
            TimeRing(snapshot: snapshot, countsUp: type == .stopwatch && phase.kind == .work, colors: colors)
                // A stroke straddles its path, so half the line's width keeps the ring inside its frame.
                .padding(10)
            if type == .stopwatch {
                StopwatchLineView(snapshot: snapshot, length: stopwatchLength, line: stopwatchLine, colors: colors)
            } else {
                RoundLineView(line: snapshot.roundLine, colors: colors)
            }
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

/// The ring and the time left. Both read the engine's clock on every display frame.
private struct TimeRing: View {
    let snapshot: WorkoutRunner.Snapshot
    let countsUp: Bool
    let colors: PhaseColors

    private let lineWidth: CGFloat = 20

    var body: some View {
        ZStack {
            Circle().stroke(colors.track, lineWidth: lineWidth)
            TimelineView(.animation(paused: snapshot.isPaused)) { _ in
                let now = ContinuousClock.now
                let left = snapshot.timeLeft(at: now)
                let shown = countsUp ? elapsedText(left: left) : left.clockText
                let fraction = countsUp ? 1 - snapshot.fractionLeft(at: now) : snapshot.fractionLeft(at: now)

                ZStack {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(colors.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    // No `.numericText()` transition, because it blurred the digits.
                    Text(shown)
                        // Set above any phone's width, so the ring alone decides the size. From 3 m that's about
                        // 12.6 arcmin on an iPhone SE to 16.3 on the largest phone, under the 20 to 22 usually
                        // cited for reading at a distance. The owner accepted that to keep the ring's size.
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

    /// Whole seconds gone, rounded down, so it reads 00:00 as Work starts and its full length only as it ends.
    private func elapsedText(left: Duration) -> String {
        let elapsed = (snapshot.phase?.duration ?? .zero) - left
        return Duration.seconds(max(0, elapsed.components.seconds)).clockText
    }
}

/// PROTOTYPE: what sits under a Stopwatch's ring. During Prepare every option but "nothing" shows the length
/// to come, the way Intervals shows "8 Rounds".
private struct StopwatchLineView: View {
    let snapshot: WorkoutRunner.Snapshot
    let length: Duration
    let line: StopwatchLine
    let colors: PhaseColors

    private let numberSize: CGFloat = 64

    var body: some View {
        Group {
            if snapshot.isPaused {
                Text("Paused")
                    .font(.system(size: 42, weight: .semibold))
            } else if line == .none {
                // Holds the line's height, so Paused appearing doesn't move the ring.
                Color.clear
            } else if snapshot.phase?.kind == .prepare {
                pair(number: length.clockText, caption: "Stopwatch", trailing: true)
                    .accessibilityLabel("\(spoken(length)) Stopwatch")
            } else if line == .length {
                pair(number: length.clockText, caption: "of", trailing: false)
                    .accessibilityLabel("of \(spoken(length))")
            } else {
                TimelineView(.animation(paused: snapshot.isPaused)) { _ in
                    let left = snapshot.timeLeft(at: .now)
                    pair(number: left.clockText, caption: "left", trailing: true)
                        .accessibilityLabel("\(spoken(left)) left")
                }
            }
        }
        .foregroundStyle(colors.text)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(height: numberSize * 1.15)
    }

    private func pair(number: String, caption: String, trailing: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            if !trailing { captionText(caption) }
            Text(number)
                .font(.system(size: numberSize, weight: .semibold).monospacedDigit())
            if trailing { captionText(caption) }
        }
        .accessibilityElement(children: .ignore)
    }

    private func captionText(_ caption: String) -> some View {
        Text(caption)
            .font(.system(size: 32, weight: .medium))
            .opacity(0.72)
    }

    private func spoken(_ duration: Duration) -> String {
        Duration.seconds(duration.components.seconds)
            .formatted(.units(allowed: [.minutes, .seconds], width: .wide))
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
