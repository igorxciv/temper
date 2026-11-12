import SwiftUI
import TemperCore

/// Open Rounds' complete screen, after Stop: each Round's Work time as a line on the board, ticked off, then the total
/// written under the last of them with the number of Rounds, and whether it goes to Health.
///
/// The heading, the Rounds and the total scroll together, so the total always sits under the lines it adds up, and
/// only Close stays put. Has to hold together on the iPhone SE, 375 by 667 pt, at every text size.
struct RoundsCompleteScreen: View {
    let summary: RoundsSummary
    /// The Workout record's active time, which decides whether it goes to Health.
    let activeTime: Duration
    let health: HealthSaves
    let close: () -> Void

    @State private var isTicked = false

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        // With Reduce Motion the lines arrive already ticked, so nothing is drawn in.
        let isDrawn = isTicked || reduceMotion

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                CompleteHeading()
                VStack(alignment: .leading, spacing: 8) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.rows) { row in
                            RoundLine(row: row, ink: ink, isDrawn: isDrawn)
                        }
                    }
                    MarkerUnderline()
                        .trim(from: 0, to: isDrawn ? 1 : 0)
                        .stroke(ink.marker, style: .marker)
                        .frame(height: 10)
                        // Drawn once the last tick is, as the line a total is written under.
                        .animation(
                            .easeOut(duration: 0.35).delay(RoundLine.lastTickDelay(of: summary.rows) + 0.4),
                            value: isDrawn
                        )
                        .accessibilityHidden(true)
                }
                CompleteTotal(
                    time: activeTime.shortClockText(rounding: .down), spokenTime: summary.spokenTotal,
                    caption: summary.countText)
                CompleteHealthLine(health: health, activeTime: activeTime)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            CompleteCloseButton(close: close)
        }
        .background(ink.ground.ignoresSafeArea())
        .task {
            // A beat to take in the screen before the first stroke.
            try? await Task.sleep(for: .seconds(0.3))
            isTicked = true
        }
    }
}

/// One Round on the board: ticked, "Round 3" in black marker at the left, its Work time in Work's ink at the right.
private struct RoundLine: View {
    /// Rounds past this many are ticked with the last of them, so a long Workout isn't still being ticked a minute on.
    private static let staggeredRounds = 10
    /// How long after one tick starts the next one does.
    private static let stagger = 0.18

    let row: RoundsSummary.Row
    let ink: BoardInk
    let isDrawn: Bool

    /// How long after the first tick starts the last one does.
    static func lastTickDelay(of rows: [RoundsSummary.Row]) -> Double {
        Double(min(max(rows.count - 1, 0), staggeredRounds)) * stagger
    }

    var body: some View {
        let work = ink.ink(.work)
        let order = min(row.round - 1, Self.staggeredRounds)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MarkerTick()
                .trim(from: 0, to: isDrawn ? 1 : 0)
                .stroke(work, style: .marker)
                .frame(width: 20, height: 16)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                .animation(.easeOut(duration: 0.3).delay(Double(order) * Self.stagger), value: isDrawn)
            Text("Round \(row.round)")
                .font(.title2.bold())
                .foregroundStyle(ink.marker)
            Spacer(minLength: 8)
            Text(row.time)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(work)
                .layoutPriority(1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenTime)
    }
}
