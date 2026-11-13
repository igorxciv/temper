import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start.
///
/// The Plan is made on the iPhone by Apple Intelligence, and shown before Start with each Phase in its color, as setup
/// shows it, so a misheard number is caught before the Workout runs. The description and the last Plan are remembered,
/// so a Workout can run again after it ends.
struct DescribeScreen: View {
    @Bindable var remembered: RememberedValues
    let start: (Workout, HealthRecord.ActivityType) -> Void

    @State private var isWriting = false
    @State private var problem: String?
    @FocusState private var isEditing: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let unavailable = PlanWriter.unavailableReason
        let plan = remembered.describedPlan
        let workout = plan.flatMap { try? $0.makeWorkout() }
        let board = plan.map(PlanBoard.init(plan:))
        let canWrite = !isWriting && unavailable == nil && !remembered.workoutDescription.trimmed.isEmpty

        Form {
            Section {
                TextField(
                    "Today's Workout",
                    text: $remembered.workoutDescription,
                    // Dimmer than typed text but still about 4.5:1, since the system's placeholder gray is too faint on
                    // the raised row.
                    prompt: Text("10 sets, open Work, exactly 1 minute of Rest between them")
                        .foregroundStyle(colors.secondary.opacity(0.78)),
                    axis: .vertical
                )
                .lineLimit(3...8)
                .focused($isEditing)
                .foregroundStyle(colors.text)
                .listRowBackground(colors.raised)
            } header: {
                Text("Today's Workout").foregroundStyle(colors.secondary)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        unavailable
                            ?? "Say how many Rounds, and how long each Work and Rest lasts. A Work with no time ends when you tap Done."
                    )
                    .foregroundStyle(colors.secondary)
                    if let problem {
                        Text(problem)
                            .foregroundStyle(colors.text)
                    }
                }
            }

            if let board {
                Section {
                    ForEach(board.items.indices, id: \.self) { index in
                        switch board.items[index] {
                        case .line(let line):
                            PlanLineRow(line: line)
                                .listRowBackground(colors.raised)
                        case .rounds(let count, let lines, _):
                            RoundsHeaderRow(count: count)
                                .listRowBackground(colors.raised)
                            ForEach(lines.indices, id: \.self) { lineIndex in
                                PlanLineRow(line: lines[lineIndex])
                                    .padding(.leading, 20)
                                    .listRowBackground(colors.raised)
                            }
                        }
                    }
                } header: {
                    Text("Plan").foregroundStyle(colors.secondary)
                } footer: {
                    if let note = board.note {
                        Text(note).foregroundStyle(colors.secondary)
                    }
                }

                // Start is the action once there's a Plan, so making another is a quieter row.
                Section {
                    Button {
                        write()
                    } label: {
                        HStack {
                            Text("Make New Plan")
                            Spacer()
                            if isWriting {
                                ProgressView()
                            }
                        }
                    }
                    .foregroundStyle(canWrite ? colors.accent : colors.secondary)
                    .disabled(!canWrite)
                    .listRowBackground(colors.raised)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Describe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            Group {
                if let plan, let workout, let board {
                    StartButton(workout: workout, board: board) {
                        start(workout, plan.activity)
                    }
                } else {
                    makePlanButton(isEnabled: canWrite, colors: colors)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .padding(.horizontal)
        }
    }

    /// Before there's a Plan, making one is the screen's action, in Start's place.
    private func makePlanButton(isEnabled: Bool, colors: InkColors) -> some View {
        Button {
            write()
        } label: {
            HStack(spacing: 10) {
                if isWriting {
                    ProgressView()
                        .tint(colors.onAccent)
                }
                Text(isWriting ? "Making Plan…" : "Make Plan")
            }
            .font(.title2.bold())
            .foregroundStyle(isEnabled || isWriting ? AnyShapeStyle(colors.onAccent) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(colors.accent)
        .disabled(!isEnabled)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
    }

    /// Asks for a Plan, and keeps it only if it can run, so Start never offers a Plan that can't.
    private func write() {
        isEditing = false
        isWriting = true
        problem = nil
        let description = remembered.workoutDescription.trimmed
        Task {
            defer { isWriting = false }
            do throws(PlanWriter.Failure) {
                let plan = try await PlanWriter.draft(for: description).plan
                do throws(PlanProblem) {
                    _ = try plan.makeWorkout()
                    remembered.describedPlan = plan
                } catch {
                    remembered.describedPlan = nil
                    problem = "That Plan can't run. \(error.explanation) Try describing it another way."
                }
            } catch {
                remembered.describedPlan = nil
                problem = error.explanation
            }
        }
    }
}

/// One Phase of the Plan: its name in its color, as setup's words are, and its time at the right.
private struct PlanLineRow: View {
    let line: PlanBoard.Line

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        HStack(alignment: .firstTextBaseline) {
            Text(line.kind.name)
                .font(.title3.bold())
                .foregroundStyle(PhaseColors(kind: line.kind, contrast: contrast).ring)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(line.time)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(colors.text)
                if let caption = line.caption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(colors.secondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.spokenText)
    }
}

/// The count over a Rounds Block's Phases, which sit indented under it.
private struct RoundsHeaderRow: View {
    let count: Plan.Block.Count

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(InkColors(contrast: contrast).text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var text: String {
        switch count {
        case .times(1): "1 Round"
        case .times(let times): "\(times) Rounds"
        case .untilStop: "Rounds until Stop"
        }
    }
}

extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
