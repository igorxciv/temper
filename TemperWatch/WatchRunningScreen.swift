import SwiftUI
import TemperCore

/// The iPhone's running screen shrunk, for every Workout Type and Phase: the Phase name in its color with the
/// heart-rate slot on the same row, the time, a thin bar, the iPhone's line, then the 56 pt capsule.
///
/// The time and bar are drawn from the Phase's dates, so nothing has to arrive from the iPhone between its events.
/// Always On keeps the same layout on black, so nothing moves on wrist-down.
///
/// Only the capsule takes a tap, so a tap anywhere above it does nothing.
struct WatchRunningScreen: View {
    let phase: WatchPhase
    /// Sends a tap to the iPhone. The update it causes redraws the screen.
    let tap: (WatchCommand) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let colors = PhaseColors(kind: phase.kind, contrast: contrast)
        let dim = isLuminanceReduced

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(phase.kind.name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(colors.ring.opacity(dim ? 0.55 : 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                HeartRateSlot()
            }
            // Aligned to the Phase's start, every whole second of the time lands on a tick. Awake, the bar moves
            // four times a second. Paused, nothing moves.
            TimelineView(
                .periodic(from: phase.start, by: phase.pausedAt != nil ? 3_600 : dim ? 1 : 0.25)
            ) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.time(at: context.date))
                        .font(.system(size: 54, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colors.text.opacity(dim ? 0.7 : 1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(phase.spokenTime(at: context.date))
                    PhaseBar(fill: phase.fill(at: context.date), colors: colors, dim: dim)
                        .padding(.vertical, 3)
                }
            }
            LineText(line: phase.line, colors: colors, dim: dim)
            Spacer(minLength: 4)
            QuickActionCapsule(capsule: phase.capsule, colors: colors, dim: dim, tap: tap)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background((dim ? Color.black : colors.background).ignoresSafeArea())
    }
}

/// Where the heart rate and its Zone will show. Empty until the Watch reads heart rate.
private struct HeartRateSlot: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

/// A thin bar of the Phase's progress. An open Phase shows only the track.
private struct PhaseBar: View {
    let fill: Double
    let colors: PhaseColors
    let dim: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(colors.track.opacity(dim ? 0.6 : 1))
                if fill > 0 {
                    Capsule()
                        .fill(colors.ring.opacity(dim ? 0.55 : 1))
                        .frame(width: max(proxy.size.width * fill, 5))
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// The line under the iPhone's ring, styled the same way: the value, with its smaller caption on the same side.
private struct LineText: View {
    let line: RingLine?
    let colors: PhaseColors
    let dim: Bool

    var body: some View {
        Group {
            switch line {
            case .value(let value, let caption, let spoken):
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if case .before(let text) = caption {
                        CaptionText(text: text)
                    }
                    Text(value)
                        .font(.system(size: 19, weight: .semibold).monospacedDigit())
                    if case .after(let text) = caption {
                        CaptionText(text: text)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
            case .paused:
                Text("Paused")
                    .font(.system(size: 19, weight: .semibold))
            case nil:
                Text(" ")
                    .font(.system(size: 19, weight: .semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(colors.text.opacity(dim ? 0.6 : 1))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct CaptionText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium).monospacedDigit())
            .opacity(0.72)
    }
}

/// The iPhone's quick action in the full-width capsule. A dimmed Done stays in place and takes no tap.
private struct QuickActionCapsule: View {
    let capsule: WatchPhase.Capsule
    let colors: PhaseColors
    let dim: Bool
    let tap: (WatchCommand) -> Void

    var body: some View {
        // A dimmed Done reads as Done but sends nothing.
        let command = capsule.command
        let shown = command ?? .done
        WatchCapsule(title: shown.title, symbol: shown.symbol, fill: colors.ring, ink: colors.background, dim: dim) {
            if let command {
                tap(command)
            }
        }
        .disabled(command == nil)
        .opacity(command == nil ? 0.3 : 1)
    }
}

#Preview("Intervals Work") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .work, round: 4, start: .now.addingTimeInterval(-12), end: .now.addingTimeInterval(28), pausedAt: nil,
            countsUp: false, line: .value("4", caption: .after("of 8"), spoken: "Round 4 of 8"), capsule: .pause),
        tap: { _ in })
}

#Preview("Open Rounds Rest") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .rest, round: 3, start: .now.addingTimeInterval(-18), end: .now.addingTimeInterval(42), pausedAt: nil,
            countsUp: false,
            line: .value("1:42", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 1 minute 42 seconds"),
            capsule: .doneDimmed),
        tap: { _ in })
}

#Preview("Stopwatch, Paused") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .work, round: nil, start: .now.addingTimeInterval(-134), end: .now.addingTimeInterval(466),
            pausedAt: .now, countsUp: true, line: .paused, capsule: .resume),
        tap: { _ in })
}
