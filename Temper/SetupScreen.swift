import SwiftUI
import TemperCore

/// Where a Workout Type gets its values, and where End Workout and Close return to.
///
/// Every Phase the Workout Type runs has a row, in the order it runs, so the screen shows the Workout as it will run:
/// Stopwatch's Work counts on past its length, and Open Rounds' open Work is there though it has nothing to set.
///
/// Has to fit on the iPhone SE, 375 by 667 pt, with the tab bar, Start and a Preset's subtitle, at every text
/// size.
struct SetupScreen: View {
    let workoutType: WorkoutType
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    @State private var editing: WorkoutValue?
    @State private var isNamingPreset = false
    @State private var isManagingPresets = false

    @Environment(\.colorSchemeContrast) private var contrast

    /// The tallest a row grows, so a two-row Workout Type doesn't stretch each row across half the screen. The
    /// space left over gathers once, under the rows.
    private let maxRowHeight: CGFloat = 168

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let settings = remembered[workoutType]
        let presets = remembered.presets(of: workoutType)
        let workout = workoutType.makeWorkout(from: settings)
        let board = PlanBoard(workoutType: workoutType, settings: settings)
        let rows = SetupLine.lines(of: board, settings: settings)

        // The rows fill the screen and don't need to scroll. The scroll view is there so a drag stretches them
        // and they spring back.
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    rowView(row)
                        .frame(maxWidth: .infinity, maxHeight: maxRowHeight)

                    if row.id != rows.last?.id {
                        Rectangle().fill(colors.separator).frame(height: 1)
                    }
                }
                Spacer(minLength: 0)
            }
            // The visible height, inside the bars, so the rows share it as they did before they could scroll.
            .containerRelativeFrame(.vertical)
            .padding(.horizontal)
        }
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        // In a bar, so Start stays put while the rows stretch under it.
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 12) {
                if let note = board.note {
                    // What the rows alone don't say, as that a Stopwatch's Work counts on past its length.
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        // Start keeps its place on the iPhone SE at the largest sizes.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
                StartButton(workout: workout, board: board) {
                    start(workoutType, workout)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .padding(.horizontal)
        }
        // The name sheet's keyboard would otherwise squeeze the rows behind the sheet.
        .ignoresSafeArea(.keyboard)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle(workoutType.title)
        // An empty subtitle draws nothing, which keeps the screen's identity when a Preset is first picked.
        // VoiceOver reads it after the title, and its text already spells out the state, so it needs no label.
        .navigationSubtitle(presets.subtitle(for: settings) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // In the title, so a Preset is two taps away between sets.
        .toolbarTitleMenu {
            presetMenu(presets, settings: settings)
        }
        // And in the toolbar, where the bookmark says Presets exist before the title's chevron is found.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Presets", systemImage: "bookmark") {
                    presetMenu(presets, settings: settings)
                }
            }
        }
        #if DEBUG
            // `-debugEdit Work` opens a value's sheet at launch, so the Simulator can show it with no taps.
            .task {
                let name = UserDefaults.standard.string(forKey: "debugEdit")
                editing = workoutType.values.first { $0.title == name }
            }
        #endif
        .sheet(item: $editing) { value in
            ValueSheet(value: value, amount: settings[value]) { draft in
                remembered[workoutType][value] = draft
            }
        }
        .sheet(isPresented: $isNamingPreset) {
            PresetNameSheet(title: "New Preset") { name in
                remembered.presets(of: workoutType).nameProblem(name)
            } save: { name throws(PresetNameProblem) in
                try remembered.saveAsNewPreset(named: name, of: workoutType)
            }
        }
        .sheet(isPresented: $isManagingPresets) {
            ManagePresetsSheet(workoutType: workoutType, remembered: remembered)
        }
    }

    /// A row that sets a value is a button that opens it. Open Rounds' open Work has nothing to set, so it only reads.
    @ViewBuilder private func rowView(_ row: SetupLine) -> some View {
        if let value = row.value {
            Button {
                editing = value
            } label: {
                ValueRow(line: row)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.spokenText)
        } else {
            ValueRow(line: row)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.spokenText)
        }
    }

    private func presetMenu(_ presets: PresetList, settings: WorkoutSettings) -> some View {
        PresetMenu(list: presets, isModified: presets.isModified(settings)) { id in
            remembered.pickPreset(id, of: workoutType)
        } saveAsNew: {
            isNamingPreset = true
        } update: {
            remembered.updatePickedPreset(of: workoutType)
        } manage: {
            isManagingPresets = true
        }
    }
}

/// One setup row's content: the value's word, its text, and what follows the text, if anything.
private struct SetupLine: Identifiable {
    let title: String
    /// The Phase the row is, or `nil` for Rounds.
    let kind: Phase.Kind?
    let text: String
    let caption: String?
    /// The value the row sets, or `nil` if it has nothing to set.
    let value: WorkoutValue?
    let spokenText: String

    var id: String { title }

    /// The board's lines, with a Rounds row before a Rounds Block whose count can be set.
    static func lines(of board: PlanBoard, settings: WorkoutSettings) -> [SetupLine] {
        board.items.flatMap { item -> [SetupLine] in
            switch item {
            case .line(let line):
                return [SetupLine(line, settings: settings)]
            case .rounds(_, let lines, let value):
                let count = value.map { value in
                    let text = value.text(for: settings[value])
                    return SetupLine(
                        title: value.title, kind: nil, text: text, caption: nil, value: value,
                        spokenText: "\(value.title), \(text)")
                }
                return (count.map { [$0] } ?? []) + lines.map { SetupLine($0, settings: settings) }
            }
        }
    }

    private init(
        title: String, kind: Phase.Kind?, text: String, caption: String?, value: WorkoutValue?, spokenText: String
    ) {
        self.title = title
        self.kind = kind
        self.text = text
        self.caption = caption
        self.value = value
        self.spokenText = spokenText
    }

    private init(_ line: PlanBoard.Line, settings: WorkoutSettings) {
        title = line.kind.name
        kind = line.kind
        // A value's own text, as "00:40" or "Off", so the row reads as the value sheet sets it.
        text = line.value.map { $0.text(for: settings[$0]) } ?? line.time
        caption = line.caption
        value = line.value
        spokenText = line.spokenText
    }
}

/// One setup row: the hollow word at the left, scaled to the space the text leaves so the whole word shows on every
/// screen, and the text at the right.
private struct ValueRow: View {
    let line: SetupLine

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        HStack(spacing: 12) {
            // An overlay on empty space, because the word's own width must not widen the row.
            Color.clear
                .overlay(alignment: .leading) {
                    HollowWord(
                        word: line.title,
                        // Rounds in a neutral rather than Start's amber, so amber only ever means act here.
                        color: line.kind.map { PhaseColors(kind: $0, contrast: contrast).ring } ?? colors.secondary,
                        fill: colors.background,
                        opacity: wordOpacity
                    )
                    .padding(.leading, 1)
                }
                .accessibilityHidden(true)
            VStack(alignment: .trailing, spacing: 0) {
                Text(line.text)
                    .font(.system(size: 52, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.text)
                if let caption = line.caption {
                    Text(caption)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colors.secondary)
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    /// A backdrop still, but one that reads: about 4.5:1 against the background, and 8:1 under Increase Contrast.
    /// Rounds' neutral is darker than the Phase colors, so it's set a little stronger. 45% read at about 3:1.
    private var wordOpacity: Double {
        switch (line.kind == nil, contrast == .increased) {
        case (false, false): 0.62
        case (true, false): 0.72
        case (false, true): 0.8
        case (true, true): 0.85
        }
    }
}

/// Opaque copies composited first, so the single opacity is the color you actually see. The word shrinks to fit the
/// width it's offered, down to half size, rather than being cut off.
private struct HollowWord: View {
    let word: String
    let color: Color
    let fill: Color
    let opacity: Double

    var body: some View {
        let base = Text(word)
            .font(.system(size: 60, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

        ZStack(alignment: .leading) {
            ForEach(0..<12, id: \.self) { step in
                let angle = Double(step) / 12 * 2 * .pi
                base.foregroundStyle(color).offset(x: cos(angle), y: sin(angle))
            }
            base.foregroundStyle(fill)
        }
        .compositingGroup()
        .opacity(opacity)
    }
}
