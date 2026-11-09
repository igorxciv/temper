import ActivityKit
import AppIntents
import SwiftUI
import TemperCore
import WidgetKit

/// The running Workout on the Lock Screen, in the Dynamic Island, and in the Apple Watch Smart Stack.
///
/// The system counts each Phase's time from its dates, so these views change only when the app sends a new
/// state, at a Phase change, Pause, Resume or the end.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            ActivityView(state: context.state)
        } dynamicIsland: { context in
            dynamicIsland(for: context.state)
        }
        // Small is the Apple Watch Smart Stack and CarPlay. Medium is the Lock Screen.
        .supplementalActivityFamilies([.small])
    }

    private func dynamicIsland(for state: LiveActivityState) -> DynamicIsland {
        switch state {
        case .phase(let phase):
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseName(phase: phase)
                        .font(.title2.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PhaseTime(phase: phase)
                        .font(.system(size: 40, weight: .semibold).monospacedDigit())
                        .phaseColor(phase.kind, \.text)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            PhaseLine(phase: phase)
                                .font(.headline)
                            if phase.hasBar {
                                PhaseBar(phase: phase)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let button = phase.button {
                            PhaseButton(phase: phase, button: button)
                        }
                    }
                }
            } compactLeading: {
                PhaseName(phase: phase)
                    .font(.caption.weight(.semibold))
            } compactTrailing: {
                PhaseTime(phase: phase)
                    .monospacedDigit()
                    .phaseColor(phase.kind, \.ring)
                    // A timer's text takes all the width it's offered, which would crowd the camera.
                    .frame(maxWidth: 44)
            } minimal: {
                PhaseTime(phase: phase)
                    .font(.caption2.monospacedDigit())
                    .phaseColor(phase.kind, \.ring)
            }
            // A Dynamic Island isn't a view, so it can't read the contrast setting.
            .keylineTint(PhaseColors(kind: phase.kind, contrast: .standard).ring)
        case .complete:
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    CompleteView(state: state)
                }
            } compactLeading: {
                CompleteMark()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                CompleteMark()
            }
            .keylineTint(InkColors(contrast: .standard).accent)
        }
    }
}

/// The Lock Screen banner, and the card in the Apple Watch Smart Stack.
private struct ActivityView: View {
    let state: LiveActivityState

    @Environment(\.activityFamily) private var family
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        switch state {
        case .phase(let phase):
            let colors = PhaseColors(kind: phase.kind, contrast: contrast)
            Group {
                switch family {
                case .small: SmallPhaseView(phase: phase)
                case .medium: MediumPhaseView(phase: phase)
                @unknown default: MediumPhaseView(phase: phase)
                }
            }
            .foregroundStyle(colors.text)
            .activityBackgroundTint(colors.background)
            .activitySystemActionForegroundColor(colors.text)
        case .complete:
            let colors = InkColors(contrast: contrast)
            CompleteView(state: state)
                .padding(family == .small ? 0 : 16)
                .activityBackgroundTint(colors.background)
                .activitySystemActionForegroundColor(colors.text)
        }
    }
}

private struct MediumPhaseView: View {
    let phase: LivePhase

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    PhaseName(phase: phase)
                        .font(.title2.weight(.semibold))
                    PhaseLine(phase: phase)
                        .font(.headline)
                }
                Spacer(minLength: 12)
                PhaseTime(phase: phase)
                    .font(.system(size: 48, weight: .semibold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
            if phase.hasBar || phase.button != nil {
                HStack(spacing: 12) {
                    if phase.hasBar {
                        PhaseBar(phase: phase)
                    }
                    if let button = phase.button {
                        // With no bar beside it, Done takes the whole row, the easier to hit mid-set.
                        PhaseButton(phase: phase, button: button, fillsWidth: !phase.hasBar)
                    }
                }
            }
        }
        .padding(16)
    }
}

/// Sized for the Apple Watch Smart Stack, where it's read at a glance mid-Workout, so the time comes first.
private struct SmallPhaseView: View {
    let phase: LivePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                PhaseName(phase: phase)
                    .font(.headline)
                Spacer(minLength: 4)
                PhaseLine(phase: phase)
                    .font(.caption.weight(.semibold))
            }
            HStack {
                PhaseTime(phase: phase)
                    .font(.system(size: 36, weight: .semibold).monospacedDigit())
                Spacer(minLength: 4)
                if let button = phase.button {
                    PhaseButton(phase: phase, button: button)
                }
            }
            if phase.hasBar {
                PhaseBar(phase: phase)
            }
        }
    }
}

/// The Phase's button: Pause or Resume in Intervals and Stopwatch, and Done in Open Rounds' running Work and in a
/// Stopwatch's running Work past its set length. The tap
/// runs in the app, which reads the clock as the tap arrives, the same as a tap on the running screen.
private struct PhaseButton: View {
    let phase: LivePhase
    let button: LivePhase.Button
    var fillsWidth = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            switch button {
            case .pause:
                Button(intent: PauseWorkoutIntent()) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            case .resume:
                Button(intent: ResumeWorkoutIntent()) {
                    Label("Resume", systemImage: "play.fill")
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
            case .done:
                Button(intent: DoneWorkoutIntent()) {
                    Text("Done")
                        .lineLimit(1)
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                }
                .buttonBorderShape(.capsule)
            }
        }
        .font(.title3.bold())
        .buttonStyle(.bordered)
        .tint(PhaseColors(kind: phase.kind, contrast: contrast).ring)
    }
}

private struct PhaseName: View {
    let phase: LivePhase

    var body: some View {
        Text(phase.kind.name)
            .phaseColor(phase.kind, \.ring)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// The time the system counts, held while Paused. It reads the time left, or the time elapsed in a Stopwatch's Work
/// and an open Phase.
private struct PhaseTime: View {
    let phase: LivePhase

    var body: some View {
        Text(
            timerInterval: phase.interval,
            pauseTime: phase.pausedAt,
            countsDown: !phase.countsUp,
            showsHours: false
        )
        .lineLimit(1)
    }
}

private struct PhaseLine: View {
    let phase: LivePhase

    var body: some View {
        Text(phase.line)
            .opacity(0.72)
            .lineLimit(1)
            .accessibilityLabel(phase.spokenLine)
    }
}

/// The ring as a bar. It empties as the time counts down and fills as a Stopwatch counts up, staying full past its
/// set length. An open Phase has none.
private struct PhaseBar: View {
    let phase: LivePhase

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if phase.isPaused {
                ProgressView(value: phase.pausedFill)
            } else {
                ProgressView(timerInterval: phase.barInterval, countsDown: !phase.countsUp) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
        }
        .tint(PhaseColors(kind: phase.kind, contrast: contrast).ring)
        // The time beside it already says how far along the Phase is.
        .accessibilityHidden(true)
    }
}

private struct CompleteView: View {
    let state: LiveActivityState

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        HStack(spacing: 12) {
            CompleteMark()
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout complete")
                    .font(.headline)
                    .foregroundStyle(colors.text)
                if case .complete(let total?, let spokenTotal?) = state {
                    Text(total)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(colors.secondary)
                        .accessibilityLabel(spokenTotal)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CompleteMark: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(InkColors(contrast: contrast).accent)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Colors the content with one of a Phase's colors, at the contrast the viewer has set.
    fileprivate func phaseColor(_ kind: Phase.Kind, _ color: KeyPath<PhaseColors, Color>) -> some View {
        modifier(PhaseColor(kind: kind, color: color))
    }
}

private struct PhaseColor: ViewModifier {
    let kind: Phase.Kind
    let color: KeyPath<PhaseColors, Color>

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.foregroundStyle(PhaseColors(kind: kind, contrast: contrast)[keyPath: color])
    }
}
