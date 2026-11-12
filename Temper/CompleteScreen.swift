import SwiftUI
import TemperCore

/// The complete screen of a Workout with no open Phase, as Intervals, Stopwatch or a described Plan: the board it ran
/// from with every line ticked off, the total written under a marker line, and whether it goes to Health.
///
/// The ticks are drawn one line after the next as the screen appears, the way a coach ticks a board. A Workout whose
/// board isn't known, as one a debug launch started, shows only the heading and the total.
struct CompleteScreen: View {
    /// The board of the Plan that ran, or `nil` if it isn't known.
    let board: PlanBoard?
    /// The Workout record's active time, the same total the Live Activity shows.
    let total: Duration
    let health: HealthSaves
    let close: () -> Void

    @State private var isTicked = false

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        // With Reduce Motion the board arrives already ticked, so nothing is drawn in.
        let isDrawn = isTicked || reduceMotion

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                CompleteHeading()
                if let board = board.map(Self.ran) {
                    VStack(alignment: .leading, spacing: 8) {
                        PlanBoardView(board: board, ticked: true, ticksDrawn: isDrawn)
                        MarkerUnderline()
                            .trim(from: 0, to: isDrawn ? 1 : 0)
                            .stroke(ink.marker, style: .marker)
                            .frame(height: 10)
                            // Drawn once the last tick is, as the line a total is written under.
                            .animation(
                                .easeOut(duration: 0.35).delay(Double(board.allLines.count) * 0.18 + 0.1),
                                value: isDrawn
                            )
                            .accessibilityHidden(true)
                    }
                }
                CompleteTotal(
                    time: total.shortClockText(rounding: .down),
                    spokenTime: "Total \(total.spokenText(rounding: .down))")
                CompleteHealthLine(health: health, activeTime: total)
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

    /// The board as it ran: an Off line didn't run, so it isn't ticked off, and a Rounds Block left with no lines goes.
    private static func ran(_ board: PlanBoard) -> PlanBoard {
        PlanBoard(
            items: board.items.compactMap { item in
                switch item {
                case .line(let line):
                    return line.length == .off ? nil : item
                case .rounds(let count, let lines, let value):
                    let ran = lines.filter { $0.length != .off }
                    return ran.isEmpty ? nil : .rounds(count, ran, value: value)
                }
            })
    }
}

/// The total, written large at the board's time column with its label at the left, as both complete screens show it.
struct CompleteTotal: View {
    let time: String
    /// What VoiceOver reads, with the label, as "Total 23 minutes 10 seconds".
    let spokenTime: String
    /// What follows the label, as "8 Rounds".
    var caption: String?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Total")
                    .font(.title2.bold())
                    .foregroundStyle(ink.marker)
                if let caption {
                    Text(caption)
                        .font(.headline)
                        .foregroundStyle(ink.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            // A fixed size, like the board's times, so the total reads as the biggest number on the board.
            Text(time)
                .font(.system(size: 60, weight: .bold).monospacedDigit())
                .foregroundStyle(ink.marker)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([spokenTime, caption].compactMap(\.self).joined(separator: ", "))
    }
}
