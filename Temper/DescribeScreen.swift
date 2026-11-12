import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start.
///
/// The Plan is made on the iPhone by Apple Intelligence, and written up on the board before Start exactly as the
/// Plan screen writes a Workout Type, so a misheard number is caught before the Workout runs. The description and
/// the last Plan are remembered, so a Workout can run again after it ends.
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

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 28) {
                descriptionField(ink: ink, unavailable: unavailable)
                makePlan(ink: ink, unavailable: unavailable, hasPlan: plan != nil)
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

    /// The description, set into the board as a panel, with what to say, or why Describe can't run, under it.
    private func descriptionField(ink: BoardInk, unavailable: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Workout")
                .font(.headline)
                .foregroundStyle(ink.marker)
                .accessibilityAddTraits(.isHeader)
            TextField(
                "Today's Workout",
                text: $remembered.workoutDescription,
                prompt: Text("10 sets, open Work, exactly 1 minute of Rest between them")
                    .foregroundStyle(ink.secondary),
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
        }
    }

    /// Make Plan, with the problem from the last try beside it, or an example to copy before the first Plan.
    private func makePlan(ink: BoardInk, unavailable: String?, hasPlan: Bool) -> some View {
        let title = hasPlan ? "Make New Plan" : "Make Plan"

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                write()
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                    if isWriting {
                        ProgressView()
                            .tint(ink.marker)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .tint(ink.marker)
            .disabled(isWriting || unavailable != nil || remembered.workoutDescription.trimmed.isEmpty)
            // The spinner says nothing to VoiceOver, so the label carries the state.
            .accessibilityLabel(isWriting ? "Making Plan" : title)

            if let problem {
                Label {
                    Text(problem)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.subheadline)
                .foregroundStyle(ink.ink(.work))
            } else if !hasPlan {
                Text("Try: “Prepare 10 seconds, then 6 Rounds of 30 seconds Work and 30 seconds Rest.”")
                    .font(.subheadline)
                    .foregroundStyle(ink.secondary)
            }
        }
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

extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
