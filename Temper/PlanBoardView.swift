import SwiftUI
import TemperCore

/// A Plan written up on the board: each Phase's name in its marker ink at the left, its time in one tabular column
/// at the right, and a Rounds Block's lines held in a marker bracket under its count.
///
/// With `edit`, a line or a count that names a setup value is a button that opens that value; without it, the board
/// only reads. The sizes are fixed, as the setup words were, so a line reads at arm's length on every iPhone.
struct PlanBoardView: View {
    let board: PlanBoard
    var edit: ((WorkoutValue) -> Void)?
    /// Lines already run, ticked off in marker, as the complete screen shows them.
    var ticked = false
    /// Whether the ticks are drawn. Turning it on draws them as a marker stroke would, one line after the next from
    /// the top, so the complete screen can start with it off and tick the board as it appears.
    var ticksDrawn = true

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        let firstLines = firstLineNumbers

        VStack(alignment: .leading, spacing: 4) {
            ForEach(board.items.indices, id: \.self) { index in
                switch board.items[index] {
                case .line(let line):
                    BoardLineRow(line: line, ink: ink, tick: tick(firstLines[index]), edit: edit)
                case .rounds(let count, let lines, let value):
                    RoundsBracket(count: count, value: value, ink: ink, edit: edit) {
                        ForEach(lines.indices, id: \.self) { lineIndex in
                            BoardLineRow(
                                line: lines[lineIndex], ink: ink, tick: tick(firstLines[index] + lineIndex),
                                edit: edit)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    /// Each item's first line, counted from 0 at the top, so each tick knows when to be drawn.
    private var firstLineNumbers: [Int] {
        var next = 0
        return board.items.map { item in
            defer {
                switch item {
                case .line: next += 1
                case .rounds(_, let lines, _): next += lines.count
                }
            }
            return next
        }
    }

    private func tick(_ lineNumber: Int) -> BoardLineRow.Tick? {
        ticked ? BoardLineRow.Tick(lineNumber: lineNumber, isDrawn: ticksDrawn) : nil
    }
}

/// One Phase's line. A line naming a value is a button when the board edits.
private struct BoardLineRow: View {
    /// A line's tick, and where it falls in the order they're drawn.
    struct Tick {
        let lineNumber: Int
        let isDrawn: Bool
    }

    let line: PlanBoard.Line
    let ink: BoardInk
    let tick: Tick?
    let edit: ((WorkoutValue) -> Void)?

    var body: some View {
        if let edit, let value = line.value {
            Button {
                edit(value)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Changes \(line.kind.name)")
        } else {
            content
        }
    }

    private var content: some View {
        let isOff = line.length == .off
        let color = isOff ? ink.ghost : ink.ink(line.kind)
        // An Off line's time is set down at the name's size, so the lines that run lead the eye. The ghost still
        // clears 3:1 at 34 pt.
        let timeFont: Font =
            isOff
            ? .system(size: 34, weight: .semibold)
            : .system(size: 52, weight: .bold).monospacedDigit()

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let tick {
                MarkerTick()
                    .trim(from: 0, to: tick.isDrawn ? 1 : 0)
                    .stroke(color, style: .marker)
                    .animation(
                        .easeOut(duration: 0.3).delay(Double(tick.lineNumber) * 0.18),
                        value: tick.isDrawn
                    )
                    .frame(width: 22, height: 18)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            }
            Text(line.kind.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(line.time)
                    .font(timeFont)
                    .foregroundStyle(color)
                if let caption = line.caption {
                    Text(caption)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .layoutPriority(2)
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.spokenText)
    }
}

/// A Rounds Block: its count at the left, then a marker bracket holding its lines. The count is a button when the
/// board edits and the count names a value.
private struct RoundsBracket<Lines: View>: View {
    let count: Plan.Block.Count
    let value: WorkoutValue?
    let ink: BoardInk
    let edit: ((WorkoutValue) -> Void)?
    @ViewBuilder let lines: Lines

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            countLabel
                .frame(width: 64, alignment: .leading)
            MarkerBracket()
                .stroke(ink.marker, style: .marker)
                .frame(width: 16)
                .padding(.vertical, 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                lines
            }
            .padding(.leading, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var countLabel: some View {
        let text = Group {
            switch count {
            case .times(let times):
                Text("×\u{2009}\(times)")
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
            case .untilStop:
                // One block, led by the "×" a count has, with the words where its number would be, set tight so
                // they read as one count. Side by side, "× until" is wider than the count column.
                VStack(alignment: .leading, spacing: -3) {
                    Text("×")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.bottom, -2)
                    Text("until")
                    Text("Stop")
                }
                .font(.system(size: 20, weight: .bold))
            }
        }
        .foregroundStyle(ink.marker)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

        let spoken =
            switch count {
            case .times(1): "1 Round"
            case .times(let times): "\(times) Rounds"
            case .untilStop: "Rounds until Stop"
            }

        if let edit, let value {
            Button {
                edit(value)
            } label: {
                text
                    .frame(maxHeight: .infinity, alignment: .center)
                    .frame(minWidth: 44, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken)
            .accessibilityHint("Changes Rounds")
        } else {
            text
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
        }
    }
}
