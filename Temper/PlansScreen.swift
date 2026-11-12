import SwiftUI
import TemperCore

/// Every Plan at once, each a small board showing exactly what it runs: the Workout Types with their current values,
/// then each Preset, then the last described Plan and the way to describe a new one.
///
/// Opening a Preset picks it and opens its Workout Type's Plan, so its values are the ones that Start.
struct PlansScreen: View {
    @Bindable var remembered: RememberedValues

    @Environment(\.colorSchemeContrast) private var contrast

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)]

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        let presets = WorkoutType.allCases.flatMap { workoutType in
            remembered.presets(of: workoutType).presets.map { (workoutType, $0) }
        }

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(WorkoutType.allCases) { workoutType in
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

                if !presets.isEmpty {
                    CellSection(title: "Presets", ink: ink) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(presets, id: \.1.id) { workoutType, preset in
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
                }

                CellSection(title: "Described", ink: ink) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        if let plan = remembered.describedPlan {
                            NavigationLink(value: Route.describe) {
                                PlanCell(
                                    title: "Last described",
                                    subtitle: nil,
                                    board: PlanBoard(plan: plan),
                                    total: (try? plan.makeWorkout())?.totalDuration
                                )
                            }
                        }
                        NavigationLink(value: Route.describe) {
                            DescribeCell(ink: ink)
                        }
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
}

/// A heading over a group of cells.
private struct CellSection<Content: View>: View {
    let title: String
    let ink: BoardInk
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(ink.marker)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// A small board: the Plan's name, its lines in their inks, and its length.
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
                    .font(.headline)
                    .foregroundStyle(ink.marker)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(ink.secondary)
                }
            }
            .lineLimit(1)
            MiniBoard(board: board, ink: ink)
            Spacer(minLength: 0)
            Text(total.map { $0.shortClockText(rounding: .up) } ?? "Until Stop")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(ink.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(ink.ground, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(ink.rule, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 20))
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

/// The board's lines at cell size, with the same bracket.
private struct MiniBoard: View {
    let board: PlanBoard
    let ink: BoardInk

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(board.items.indices, id: \.self) { index in
                switch board.items[index] {
                case .line(let line):
                    MiniLine(line: line, ink: ink)
                case .rounds(let count, let lines, _):
                    HStack(spacing: 4) {
                        Text(count.shortText)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(ink.marker)
                            .frame(minWidth: 22, alignment: .leading)
                        MarkerBracket()
                            .stroke(ink.marker, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 6)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(lines.indices, id: \.self) { lineIndex in
                                MiniLine(line: lines[lineIndex], ink: ink)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct MiniLine: View {
    let line: PlanBoard.Line
    let ink: BoardInk

    var body: some View {
        let color = line.length == .off ? ink.ghost : ink.ink(line.kind)

        HStack(spacing: 4) {
            Text(line.kind.name)
            Spacer(minLength: 2)
            Text(line.time)
                .monospacedDigit()
        }
        .font(.subheadline.bold())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// The cell that opens Describe, for a Workout no Plan here has the shape of.
private struct DescribeCell: View {
    let ink: BoardInk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(ink.marker)
            Text("Describe a Workout")
                .font(.headline)
                .foregroundStyle(ink.marker)
            Text("Say it in words, and Temper writes up the Plan.")
                .font(.footnote)
                .foregroundStyle(ink.secondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(ink.rule, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
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
