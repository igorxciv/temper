import SwiftUI
import TemperCore

/// Where the owner describes a Workout in words, typed or dictated, and gets a Plan to check and start.
///
/// It opens on a microphone button, and the toolbar switches to the keyboard and back, which is remembered. The
/// words heard fill the description as they come, and stay there to correct by hand.
///
/// The Plan is made on the iPhone by Apple Intelligence, and shown before Start with each Phase in its color, as setup
/// shows it, so a misheard number is caught before the Workout runs. The description and the last Plan are remembered,
/// so a Workout can run again after it ends.
struct DescribeScreen: View {
    @Bindable var remembered: RememberedValues
    let start: (Workout, ActivityType) -> Void

    @State private var isWriting = false
    @State private var problem: String?
    @State private var dictation = Dictation()
    @FocusState private var isEditing: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let unavailable = PlanWriter.unavailableReason
        let plan = remembered.describedPlan
        let workout = plan.flatMap { try? $0.makeWorkout() }
        let board = plan.map(PlanBoard.init(plan:))
        let isDictating = dictation.state != .idle
        let canWrite =
            !isWriting && !isDictating && unavailable == nil && !remembered.workoutDescription.trimmed.isEmpty
        // The same words make the same Plan, so a new one waits for the description to change.
        let wordsChanged = remembered.workoutDescription.trimmed != remembered.describedPlanWords
        let showsDictate = !remembered.describesByTyping && unavailable == nil
        // Making a new Plan sits right under the microphone, or the field when typing, so it's the next tap after
        // saying it. It waits for listening to stop, and stays while the Plan is made to show it's working.
        let showsRemake =
            board != nil && wordsChanged && !isDictating && unavailable == nil
            && !remembered.workoutDescription.trimmed.isEmpty

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
                .disabled(isDictating)
                .foregroundStyle(colors.text)
                .listRowBackground(colors.raised)
            } header: {
                Text("Today's Workout").foregroundStyle(colors.secondary)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        unavailable
                            ?? "Say each part in order: how many Rounds, and how long each Prepare, Work, Rest and Cooldown lasts. Any of them can come between Rounds. A Work with no time ends when you tap Done."
                    )
                    .foregroundStyle(colors.secondary)
                    if let problem = dictation.problem ?? problem {
                        Text(problem)
                            .foregroundStyle(colors.text)
                    }
                }
            }

            if showsDictate || showsRemake {
                Section {
                    if showsDictate {
                        DictateButton(dictation: dictation, hasWords: !remembered.workoutDescription.trimmed.isEmpty)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    if showsRemake {
                        remakeButton(colors: colors)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
            }
        }
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .animation(.snappy, value: showsRemake)
        .navigationTitle("Describe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if unavailable == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        switchInput()
                    } label: {
                        if remembered.describesByTyping {
                            Label("Dictate", systemImage: "mic")
                        } else {
                            Label("Type", systemImage: "keyboard")
                        }
                    }
                }
            }
        }
        // Words heard replace the description once there are any, so tapping the microphone and saying nothing keeps
        // the old words.
        .onChange(of: dictation.transcript) { _, transcript in
            if !transcript.text.isEmpty {
                remembered.workoutDescription = transcript.text
            }
        }
        .onDisappear {
            dictation.stop()
        }
        .safeAreaBar(edge: .bottom) {
            Group {
                if let plan, let workout, let board {
                    // The Workout's audio can't share the session with the microphone, so Start waits for listening
                    // to stop.
                    StartButton(workout: workout, board: board) {
                        start(workout, plan.activity)
                    }
                    .disabled(isDictating)
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

    /// Once there's a Plan and the words change, making a new one. Start keeps the amber fill, so this is glass with an
    /// amber label, and its arrows turn while the Plan is made.
    private func remakeButton(colors: InkColors) -> some View {
        Button {
            if !isWriting {
                write()
            }
        } label: {
            Label {
                Text(isWriting ? "Making New Plan…" : "Make New Plan")
            } icon: {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .symbolEffect(.rotate, isActive: isWriting)
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(colors.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
    }

    /// Moves between the microphone and the keyboard. Moving to the keyboard stops listening and opens it.
    private func switchInput() {
        remembered.describesByTyping.toggle()
        if remembered.describesByTyping {
            dictation.stop()
            isEditing = true
        } else {
            isEditing = false
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
                    remembered.describedPlanWords = description
                } catch {
                    remembered.describedPlan = nil
                    remembered.describedPlanWords = nil
                    problem = "That Plan can't run. \(error.explanation) Try describing it another way."
                }
            } catch {
                remembered.describedPlan = nil
                remembered.describedPlanWords = nil
                problem = error.explanation
            }
        }
    }
}

/// The microphone button: tap to start listening and tap again to stop, with a line under it saying what it's doing.
private struct DictateButton: View {
    let dictation: Dictation
    /// Whether the description already has words, which listening again replaces.
    let hasWords: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var size = 76
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let isListening = dictation.state == .listening

        VStack(spacing: 12) {
            Button {
                if dictation.state == .idle {
                    dictation.start()
                } else {
                    dictation.stop()
                }
            } label: {
                Group {
                    switch dictation.state {
                    case .idle:
                        Image(systemName: "mic.fill")
                    case .listening:
                        Image(systemName: "stop.fill")
                    case .preparing, .finishing:
                        ProgressView()
                    }
                }
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(colors.accent)
                .frame(width: size, height: size)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(dictation.state == .finishing)
            .accessibilityLabel(isListening ? "Stop Dictating" : "Dictate")

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(colors.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var caption: String {
        switch dictation.state {
        case .idle: hasWords ? "Tap to say it again. Your words replace these." : "Tap and say today's Workout."
        case .preparing: "Getting ready…"
        case .listening: "Listening. Tap when you're done."
        case .finishing: "Writing it down…"
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
