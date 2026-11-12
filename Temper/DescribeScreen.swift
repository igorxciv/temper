import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start. Dictating
/// with the microphone button makes the Plan when the owner taps Stop.
///
/// The Plan is made on the iPhone by Apple Intelligence, and shown as an outline before Start, so a misheard number is
/// caught before the Workout runs. The description and the last Plan are remembered, so a Workout can run again
/// after it ends.
struct DescribeScreen: View {
    @Bindable var remembered: RememberedValues
    let start: (Workout, HealthRecord.ActivityType) -> Void

    @State private var isWriting = false
    @State private var problem: String?
    @State private var dictation = Dictation()
    @FocusState private var isEditing: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let unavailable = PlanWriter.unavailableReason
        let plan = remembered.describedPlan
        let workout = plan.flatMap { try? $0.makeWorkout() }
        let isDictating = dictation.status != .idle

        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    TextField(
                        "10 sets, open Work, exactly 1 minute of Rest between them",
                        text: $remembered.workoutDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .focused($isEditing)

                    dictateButton
                        .disabled(unavailable != nil || isWriting)
                }
            } header: {
                Text("Today's Workout")
            } footer: {
                if dictation.status == .listening {
                    Text("Listening. Tap Stop when you've said it all, and Temper makes the Plan.")
                } else {
                    Text(
                        unavailable
                            ?? "Say how many Rounds, and how long each Work and Rest lasts. A Work with no time ends when you tap Done."
                    )
                }
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
                .disabled(
                    isWriting || isDictating || unavailable != nil || remembered.workoutDescription.trimmed.isEmpty)
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
        .onDisappear {
            dictation.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Not on inactive, which the microphone permission prompt causes.
            if newPhase == .background {
                dictation.stop()
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
                // The microphone's audio session goes before a Workout's Cues take it.
                .disabled(isDictating)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityShowsLargeContentViewer()
                .padding(.top, 8)
                .padding(.bottom, 6)
                .padding(.horizontal)
            }
        }
    }

    /// Dictate while idle, Stop while listening, and a spinner while Dictation starts or settles the last words.
    /// Stop is also offered while starting, which can take a while the first time the speech model downloads.
    private var dictateButton: some View {
        Button {
            if dictation.status == .idle {
                dictate()
            } else {
                dictation.stop()
            }
        } label: {
            switch dictation.status {
            case .idle:
                Label("Dictate", systemImage: "mic")
            case .listening:
                Label("Stop Dictating", systemImage: "stop.circle.fill")
            case .starting, .stopping:
                Label {
                    Text("Stop Dictating")
                } icon: {
                    ProgressView()
                }
            }
        }
        .labelStyle(.iconOnly)
        .imageScale(.large)
        // So a tap on the rest of the row edits the description rather than pressing this.
        .buttonStyle(.borderless)
        .disabled(dictation.status == .stopping)
    }

    /// Listens to the owner describe the Workout, writing their words into the field as they speak, then makes the
    /// Plan from them. The Plan's outline is the check on a misheard number.
    private func dictate() {
        isEditing = false
        problem = nil
        Task {
            do throws(Dictation.Failure) {
                let heardWords = try await dictation.listen(replacing: remembered.workoutDescription) {
                    remembered.workoutDescription = $0
                }
                if heardWords, PlanWriter.unavailableReason == nil {
                    write()
                }
            } catch {
                problem = error.explanation
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
