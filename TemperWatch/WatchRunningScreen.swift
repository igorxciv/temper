import SwiftUI
import TemperCore

/// The iPhone's running screen shrunk, for every Workout Type and Phase: the Phase name in its color with the
/// heart-rate slot on the same row, the time, a thin bar, the iPhone's line, then the 56 pt capsule.
///
/// The time and bar are drawn from the Phase's dates, so nothing has to arrive from the iPhone between its events.
/// Always On keeps the same layout on black, so nothing moves on wrist-down.
///
/// Only the capsule takes a tap, so a tap anywhere above it does nothing.
///
/// During a dropout the time keeps drawing from the last update, and a Phase that ends holds at 00:00 rather than
/// guessing the next. "iPhone not connected" takes the line's place, and the capsule dims where it is.
struct WatchRunningScreen: View {
    let phase: WatchPhase
    /// False during a dropout.
    let isConnected: Bool
    let heartRate: LiveHeartRate
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
                HeartRateSlot(heartRate: heartRate, colors: colors, dim: dim)
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
            if isConnected {
                LineText(line: phase.line, colors: colors, dim: dim)
            } else {
                NotConnectedMark(size: 14, dim: dim)
            }
            Spacer(minLength: 4)
            QuickActionCapsule(
                capsule: phase.capsule, isConnected: isConnected, colors: colors, dim: dim, tap: tap)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background((dim ? Color.black : colors.background).ignoresSafeArea())
    }
}

/// A red heart, the latest bpm, and the Zone meter. "-- bpm" with no meter until the first reading, and no meter for
/// a Workout without Zones. Only this view observes the heart rate, so a reading redraws nothing else.
private struct HeartRateSlot: View {
    let heartRate: LiveHeartRate
    let colors: PhaseColors
    let dim: Bool

    var body: some View {
        let current = heartRate.current
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(dim ? colors.text.opacity(0.4) : HeartRateInk.heart)
            Text(current.bpmText)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(colors.text.opacity(dim ? 0.7 : 1))
            Text("bpm")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(colors.text.opacity(dim ? 0.4 : 0.72))
            if let zone = current.zone {
                ZoneMeter(zone: zone, colors: colors, dim: dim)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current.spokenText)
    }
}

/// Five short bars rising left to right, with only the current Zone's bar lit, in that Zone's color.
private struct ZoneMeter: View {
    let zone: Int
    let colors: PhaseColors
    let dim: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(1...5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index == zone ? HeartRateInk.zone(index).opacity(dim ? 0.55 : 1) : colors.track)
                    .frame(width: 3.5, height: 5 + Double(index) * 1.6)
            }
        }
        .padding(.leading, 1)
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

/// The iPhone's quick action in the full-width capsule. A dimmed Done stays in place and takes no tap. During a
/// dropout every capsule dims in place, and a tap on it only gets the failure haptic.
private struct QuickActionCapsule: View {
    let capsule: WatchPhase.Capsule
    let isConnected: Bool
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
        .opacity(command == nil || !isConnected ? 0.3 : 1)
        .accessibilityHint(isConnected ? "" : NotConnectedMark.title)
    }
}

#Preview("Intervals Work") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .work, round: 4, start: .now.addingTimeInterval(-12), end: .now.addingTimeInterval(28), pausedAt: nil,
            countsUp: false, line: .value("4", caption: .after("of 8"), spoken: "Round 4 of 8"), capsule: .pause),
        isConnected: true, heartRate: .preview(bpm: 152), tap: { _ in })
}

#Preview("Open Rounds Rest") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .rest, round: 3, start: .now.addingTimeInterval(-18), end: .now.addingTimeInterval(42), pausedAt: nil,
            countsUp: false,
            line: .value("1:42", caption: .before("Round 3 · Work"), spoken: "Round 3, Work 1 minute 42 seconds"),
            capsule: .doneDimmed),
        isConnected: true, heartRate: .preview(bpm: 118), tap: { _ in })
}

#Preview("Dropout, Phase held at 00:00") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .work, round: 4, start: .now.addingTimeInterval(-50), end: .now.addingTimeInterval(-10),
            pausedAt: nil, countsUp: false, line: .value("4", caption: .after("of 8"), spoken: "Round 4 of 8"),
            capsule: .pause),
        isConnected: false, heartRate: .preview(bpm: 152), tap: { _ in })
}

#Preview("Stopwatch, Paused") {
    WatchRunningScreen(
        phase: WatchPhase(
            kind: .work, round: nil, start: .now.addingTimeInterval(-134), end: .now.addingTimeInterval(466),
            pausedAt: .now, countsUp: true, line: .paused, capsule: .resume),
        isConnected: true, heartRate: LiveHeartRate(), tap: { _ in })
}

extension LiveHeartRate {
    /// A reading in Zones worked out for a 40-year-old with a resting rate of 60: boundaries at 132, 144, 156 and 168.
    fileprivate static func preview(bpm: Double) -> LiveHeartRate {
        let heartRate = LiveHeartRate()
        let start = Date.now
        let birth = Calendar.current.dateComponents(
            [.year, .month, .day], from: start.addingTimeInterval(-41 * 365 * 86_400))
        heartRate.current = WorkoutHeartRate(
            zones: Zones(dateOfBirth: birth, restingHeartRate: 60, start: start, calendar: .current))
        heartRate.current.record(latest: bpm, average: bpm - 14, maximum: bpm + 9)
        return heartRate
    }
}
