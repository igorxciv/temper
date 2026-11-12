import SwiftUI
import TemperCore

/// Every Plan at once, each a small board showing exactly what it runs: the Workout Types with their current values,
/// then each Preset, then the last described Plan and the way to describe a new one.
///
/// Opening a Preset picks it and opens its Workout Type's Plan, so its values are the ones that Start.
struct PlansScreen: View {
    @Bindable var remembered: RememberedValues

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        let isOneColumn = dynamicTypeSize.isAccessibilitySize
        let presets = WorkoutType.allCases.flatMap { workoutType in
            remembered.presets(of: workoutType).presets.map { (workoutType, $0) }
        }
        // Intervals has the fullest board, so it gets the whole width, and the other two share the row below it.
        let pairedTypes = WorkoutType.allCases.filter { $0 != .intervals }

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 12) {
                    workoutTypeCell(.intervals)
                    CellGrid(count: pairedTypes.count, isOneColumn: isOneColumn) { index in
                        workoutTypeCell(pairedTypes[index])
                    }
                }

                if !presets.isEmpty {
                    CellSection(title: "Presets", ink: ink) {
                        CellGrid(count: presets.count, isOneColumn: isOneColumn) { index in
                            let (workoutType, preset) = presets[index]
                            Button {
                                remembered.pickPreset(preset.id, of: workoutType)
                                remembered.path.append(.plan(workoutType))
                            } label: {
                                PlanCell(
                                    title: preset.name,
                                    subtitle: workoutType.title,
                                    board: PlanBoard(workoutType: workoutType, settings: preset.settings),
                                    total: workoutType.makeWorkout(from: preset.settings).totalDuration
                                )
                            }
                        }
                    }
                }

                if let plan = remembered.describedPlan {
                    CellSection(title: "Described", ink: ink) {
                        NavigationLink(value: Route.describe) {
                            PlanCell(
                                title: "Last described",
                                subtitle: nil,
                                board: PlanBoard(plan: plan),
                                total: (try? plan.makeWorkout())?.totalDuration
                            )
                        }
                        NavigationLink(value: Route.describe) {
                            DescribeRow(ink: ink)
                        }
                    }
                } else {
                    NavigationLink(value: Route.describe) {
                        DescribeRow(ink: ink)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .buttonStyle(.plain)
        .background(ink.ground.ignoresSafeArea())
        .navigationTitle("Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    private func workoutTypeCell(_ workoutType: WorkoutType) -> some View {
        NavigationLink(value: Route.plan(workoutType)) {
            PlanCell(
                title: workoutType.title,
                subtitle: nil,
                board: PlanBoard(workoutType: workoutType, settings: remembered[workoutType]),
                total: workoutType.makeWorkout(from: remembered[workoutType]).totalDuration
            )
        }
    }
}

/// Cells two to a row, both the height of the taller, with an odd last cell across the whole row so none sits alone
/// in half of one. At accessibility text sizes, one cell to a row.
private struct CellGrid<Cell: View>: View {
    let count: Int
    let isOneColumn: Bool
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        VStack(spacing: 12) {
            if isOneColumn {
                ForEach(0..<count, id: \.self) { index in
                    cell(index)
                }
            } else {
                ForEach(Array(stride(from: 0, to: count, by: 2)), id: \.self) { first in
                    HStack(alignment: .top, spacing: 12) {
                        cell(first)
                        if first + 1 < count {
                            cell(first + 1)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A heading over a group of cells.
private struct CellSection<Content: View>: View {
    let title: String
    let ink: BoardInk
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(ink.marker)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// A small board: the Plan's name, its lines in their inks, and its length, inside a frame drawn in marker.
private struct PlanCell: View {
    let title: String
    let subtitle: String?
    let board: PlanBoard
    let total: Duration?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(ink.marker)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(ink.secondary)
                }
            }
            .lineLimit(2)
            MiniBoard(board: board, ink: ink)
            Spacer(minLength: 0)
            Text(total.map { $0.shortClockText(rounding: .up) } ?? "Until Stop")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(ink.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            MarkerFrame()
                .stroke(ink.rule, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .contentShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [title]
        if let subtitle { parts.append(subtitle) }
        for item in board.items {
            switch item {
            case .line(let line):
                parts.append(line.spokenText)
            case .rounds(let count, let lines, _):
                let rounds =
                    switch count {
                    case .times(1): "1 Round"
                    case .times(let times): "\(times) Rounds"
                    case .untilStop: "Rounds until Stop"
                    }
                parts.append(([rounds] + lines.map(\.spokenText)).joined(separator: ", "))
            }
        }
        return parts.joined(separator: ". ")
    }
}

/// A rounded frame drawn round a cell in one marker stroke: each side bows a hair, and the stroke runs a little past
/// where it began, as a hand boxing off part of a board does.
private nonisolated struct MarkerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        // Inset so the stroke and the bows stay inside the cell.
        let box = rect.insetBy(dx: 2.5, dy: 2.5)
        let radius = min(18, box.width / 4, box.height / 4)
        let (minX, midX, maxX) = (box.minX, box.midX, box.maxX)
        let (minY, midY, maxY) = (box.minY, box.midY, box.maxY)

        var path = Path()
        path.move(to: CGPoint(x: minX + radius, y: minY + 0.5))
        path.addQuadCurve(to: CGPoint(x: maxX - radius, y: minY), control: CGPoint(x: midX, y: minY - 0.8))
        path.addQuadCurve(to: CGPoint(x: maxX, y: minY + radius), control: CGPoint(x: maxX, y: minY))
        path.addQuadCurve(to: CGPoint(x: maxX - 0.5, y: maxY - radius), control: CGPoint(x: maxX + 0.8, y: midY))
        path.addQuadCurve(to: CGPoint(x: maxX - radius, y: maxY), control: CGPoint(x: maxX, y: maxY))
        path.addQuadCurve(to: CGPoint(x: minX + radius, y: maxY - 0.5), control: CGPoint(x: midX, y: maxY + 0.8))
        path.addQuadCurve(to: CGPoint(x: minX, y: maxY - radius), control: CGPoint(x: minX, y: maxY))
        path.addQuadCurve(to: CGPoint(x: minX + 0.5, y: minY + radius), control: CGPoint(x: minX - 0.8, y: midY))
        path.addQuadCurve(to: CGPoint(x: minX + radius, y: minY), control: CGPoint(x: minX, y: minY))
        // The overrun past the start.
        path.addLine(to: CGPoint(x: minX + radius + 10, y: minY - 0.3))
        return path
    }
}

/// The board's lines at cell size, with the same bracket.
private struct MiniBoard: View {
    let board: PlanBoard
    let ink: BoardInk

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(board.items.indices, id: \.self) { index in
                switch board.items[index] {
                case .line(let line):
                    MiniLine(line: line, ink: ink)
                case .rounds(let count, let lines, _):
                    HStack(spacing: 4) {
                        Text(count.shortText)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(ink.marker)
                            .fixedSize()
                            .frame(minWidth: 24, alignment: .leading)
                        MarkerBracket()
                            .stroke(ink.marker, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 6)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(lines.indices, id: \.self) { lineIndex in
                                MiniLine(line: lines[lineIndex], ink: ink)
                            }
                        }
                        .padding(.leading, 2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// One line at cell size: name and time on one line where they fit, and the time under the name where they don't, as
/// at the largest text sizes, so neither is cut off.
private struct MiniLine: View {
    let line: PlanBoard.Line
    let ink: BoardInk

    var body: some View {
        let color = line.length == .off ? ink.ghost : ink.ink(line.kind)

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                Text(line.kind.name)
                Spacer(minLength: 6)
                Text(line.time)
                    .monospacedDigit()
            }
            .lineLimit(1)
            VStack(alignment: .leading, spacing: 0) {
                Text(line.kind.name)
                Text(line.time)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .font(.body.bold())
        .foregroundStyle(color)
    }
}

/// The way to Describe, written on the board in marker and underlined: for a Workout no Plan here has the shape of.
private struct DescribeRow: View {
    let ink: BoardInk

    var body: some View {
        HStack(spacing: 12) {
            Text("Describe a Workout")
                .font(.title2.bold())
                .foregroundStyle(ink.marker)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    MarkerUnderline()
                        .stroke(ink.marker, style: .marker)
                        .frame(height: 8)
                }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.title3.bold())
                .foregroundStyle(ink.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Say it in words, and Temper writes up the Plan.")
    }
}

extension Plan.Block.Count {
    /// The count at cell size, as "×8" or "×∞".
    fileprivate var shortText: String {
        switch self {
        case .times(let times): "×\(times)"
        case .untilStop: "×∞"
        }
    }
}
