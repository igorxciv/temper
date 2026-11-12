import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start.
///
/// The Plan is made on the iPhone by Apple Intelligence, and written up on the board before Start exactly as the
/// Plan screen writes a Workout Type, so a misheard number is caught before the Workout runs. The description and
/// the last Plan are remembered, so a Workout can run again after it ends.
///
/// The bottom bar holds one black-marker capsule: Make Plan until there's a Plan, then Start. Make New Plan moves up
/// under the description, away from Start, so a reach for Start can't throw the Plan away.
struct DescribeScreen: View {
    @Bindable var remembered: RememberedValues
    let start: (Workout, HealthRecord.ActivityType) -> Void

    @State private var isWriting = false
    @State private var problem: String?
    @FocusState private var isEditing: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        let unavailable = PlanWriter.unavailableReason
        let plan = remembered.describedPlan
        let workout = plan.flatMap { try? $0.makeWorkout() }
        let canWrite = unavailable == nil && !remembered.workoutDescription.trimmed.isEmpty

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                descriptionField(
                    ink: ink, unavailable: unavailable, hasPlan: plan != nil, canStart: workout != nil,
                    canWrite: canWrite)
                if let plan {
                    planBoard(plan, ink: ink)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            if let plan, let workout {
                StartButton(workout: workout) {
                    start(workout, plan.activity)
                }
            } else {
                MakePlanButton(title: makeTitle(hasPlan: plan != nil), isWriting: isWriting, make: write)
                    .disabled(!canWrite)
            }
        }
        .background(ink.ground.ignoresSafeArea())
        .navigationTitle("Describe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // A multi-line field's Return adds a line, so the keyboard needs its own way down. Not "Done", which
            // names the mark that ends an open Phase.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
                    isEditing = false
                }
            }
        }
    }

    /// The description, set into the board as a panel, with what to say, or why Describe can't run, under it. Once
    /// there's a Plan to Start, Make New Plan follows, and then the problem from the last try, or, before the first
    /// Plan, an example to copy.
    private func descriptionField(
        ink: BoardInk, unavailable: String?, hasPlan: Bool, canStart: Bool, canWrite: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Workout")
                .font(.headline)
                .foregroundStyle(ink.marker)
                .accessibilityAddTraits(.isHeader)
            TextField(
                "Today's Workout",
                text: $remembered.workoutDescription,
                prompt: Text("Describe today's Workout").foregroundStyle(ink.secondary),
                axis: .vertical
            )
            .lineLimit(3...8)
            .font(.body)
            .foregroundStyle(ink.marker)
            .tint(ink.marker)
            .focused($isEditing)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ink.panel, in: .rect(cornerRadius: 16, style: .continuous))
            Text(
                unavailable
                    ?? "Say how many Rounds, and how long each Work and Rest lasts. A Work with no time ends when you tap Done."
            )
            .font(.footnote)
            .foregroundStyle(ink.secondary)

            if canStart {
                makeNewPlan(ink: ink, title: makeTitle(hasPlan: hasPlan))
                    .disabled(!canWrite)
                    .padding(.top, 4)
            }
            if let problem {
                Label {
                    Text(problem)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.subheadline)
                .foregroundStyle(ink.ink(.work))
                .padding(.top, 4)
            } else if !hasPlan && unavailable == nil {
                Text("Try: “Prepare 10 seconds, then 6 Rounds of 30 seconds Work and 30 seconds Rest.”")
                    .font(.footnote)
                    .foregroundStyle(ink.secondary)
            }
        }
    }

    /// Make New Plan as a secondary glass button, since Start holds the black marker once there's a Plan.
    private func makeNewPlan(ink: BoardInk, title: String) -> some View {
        Button(action: write) {
            HStack(spacing: 8) {
                Text(title)
                if isWriting {
                    ProgressView()
                        .tint(ink.marker)
                }
            }
            .font(.headline)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(ink.marker)
        // The spinner says nothing to VoiceOver, so the label carries the state.
        .accessibilityLabel(isWriting ? "Making Plan" : title)
    }

    private func makeTitle(hasPlan: Bool) -> String {
        hasPlan ? "Make New Plan" : "Make Plan"
    }

    /// The Plan on the board, read-only, in the same lines, inks and brackets as the Plan screen.
    private func planBoard(_ plan: Plan, ink: BoardInk) -> some View {
        let board = PlanBoard(plan: plan)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Plan")
                .font(.headline)
                .foregroundStyle(ink.marker)
                .accessibilityAddTraits(.isHeader)
            PlanBoardView(board: board)
            if let note = board.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(ink.secondary)
            }
        }
    }

    /// Asks for a Plan, and keeps it only if it can run, so Start never offers a Plan that can't.
    ///
    /// A tap while a Plan is being made does nothing, so the button can stay lit beside its spinner.
    private func write() {
        guard !isWriting else { return }
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

/// Make Plan in black marker in the bottom bar, where Start takes over once there's a Plan, with a spinner beside it
/// while the Plan is being made.
private struct MakePlanButton: View {
    let title: String
    let isWriting: Bool
    let make: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        Button(action: make) {
            HStack(spacing: 10) {
                Text(title)
                if isWriting {
                    ProgressView()
                        .tint(ink.onMarker)
                }
            }
            .font(.title2.bold())
            // A disabled button's fill fades, so its label takes the board's secondary ink rather than staying light.
            // Only an empty description or Describe being unavailable disables it, never the Plan being made.
            .foregroundStyle(isEnabled ? ink.onMarker : ink.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(ink.marker)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        // The spinner says nothing to VoiceOver, so the label carries the state.
        .accessibilityLabel(isWriting ? "Making Plan" : title)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .padding(.horizontal)
    }
}

extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
