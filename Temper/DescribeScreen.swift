import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start.
///
/// The Plan is made on the iPhone by Apple Intelligence, and shown as an outline before Start, so a misheard number is
/// caught before the Workout runs. The description and the last Plan are remembered, so a Workout can run again
/// after it ends.
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

        Form {
            Section {
                TextField(
                    "10 sets, open Work, exactly 1 minute of Rest between them",
                    text: $remembered.workoutDescription,
                    axis: .vertical
                )
                .lineLimit(3...8)
                .focused($isEditing)
            } header: {
                Text("Today's Workout")
            } footer: {
                Text(
                    unavailable
                        ?? "Say how many Rounds, and how long each Work and Rest lasts. A Work with no time ends when you tap Done."
                )
            }

            Section {
                Button {
                    write()
                } label: {
                    HStack {
                        Text(plan == nil ? "Make Plan" : "Make New Plan")
                        Spacer()
                        if isWriting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isWriting || unavailable != nil || remembered.workoutDescription.trimmed.isEmpty)
            } footer: {
                if let problem {
                    Text(problem)
                }
            }

            if let plan {
                Section("Plan") {
                    ForEach(plan.outline, id: \.self) { line in
                        Text(line)
                    }
                }
            }
        }
        .navigationTitle("Describe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            if let plan, let workout {
                Button {
                    start(workout, plan.activity)
                } label: {
                    Text(workout.totalDuration.map { "Start · \($0.clockText)" } ?? "Start")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(colors.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.glassProminent)
                .tint(colors.accent)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityShowsLargeContentViewer()
                .padding(.top, 8)
                .padding(.bottom, 6)
                .padding(.horizontal)
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
