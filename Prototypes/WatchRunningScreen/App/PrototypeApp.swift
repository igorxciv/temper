// PROTOTYPE, throwaway. See Screens/Frame.swift. Runs on a real Watch. The prototype's controls page is the last
// page, a swipe left. While a Workout runs, its secondary page (Pause or Resume, and Stop) is a swipe right.

import SwiftUI
import WatchKit

@main
struct PrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeHost()
        }
    }
}

/// Where the Watch app is, from "Start on iPhone" to the complete screen.
enum Stage: Equatable {
    case idle
    /// From `handle(_:)` until the iPhone's first message. `late` decides what comes after it.
    case waiting(late: Bool)
    case running
    /// The 10 s window was missed: "Running on iPhone" until Stop.
    case late
    case complete
}

struct PrototypeHost: View {
    @State private var stage: Stage = .idle
    @State private var type: WorkoutType = .openRounds
    @State private var moment: Moment = .work
    @State private var workout = FakeWorkout(type: .openRounds, moment: .work, now: .now)
    /// What the Watch last heard, kept while the iPhone isn't connected. The screen draws from it, so a Phase that
    /// ends during the dropout holds at 00:00.
    @State private var heard: FakeWorkout?
    @State private var summary: Summary?

    @State private var heart: HeartVariant = .zoneNumber
    @State private var dropout: DropoutVariant = .line
    @State private var controls: ControlsVariant = .stacked
    @State private var stop: StopVariant = .dialog
    @State private var late: LateVariant = .message
    @State private var complete: CompleteVariant = .plain
    @State private var forcesAlwaysOn = false

    @State private var page = 1
    @State private var isConfirmingStop = false
    @State private var isStopArmed = false
    @State private var flash = 0.0

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var isAlwaysOn: Bool { forcesAlwaysOn || isLuminanceReduced }
    private var isConnected: Bool { heard == nil }

    var body: some View {
        TabView(selection: $page) {
            if stage == .running {
                secondaryPage.tag(0)
            }
            mainPage.tag(1)
            prototypeControls.tag(2)
        }
        .tabViewStyle(.page)
        .task {
            // The iPhone engine's clock. It keeps going during a dropout. Only the Watch's view of it stops.
            while !Task.isCancelled {
                if stage == .running || stage == .late {
                    workout.advance(to: .now)
                    if workout.isFinished { finish() }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var mainPage: some View {
        switch stage {
        case .idle:
            IdleScreen(isAlwaysOn: isAlwaysOn)
        case .waiting:
            WaitingScreen(isAlwaysOn: isAlwaysOn)
        case .running:
            TimelineView(.periodic(from: .now, by: isAlwaysOn ? 1 : 0.25)) { context in
                let shown = heard ?? workout
                RunningScreen(
                    input: ScreenInput(
                        frame: shown.frame(
                            at: context.date, bpm: FakeHeart.bpm(type: type, phase: shown.phase, at: context.date)),
                        isAlwaysOn: isAlwaysOn,
                        heart: heart,
                        dropout: isConnected ? nil : dropout,
                        tap: quickAction
                    )
                )
            }
            .overlay { Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false) }
        case .late:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                RunningOnIPhoneScreen(
                    variant: late, frame: workout.frame(at: context.date, bpm: nil), isAlwaysOn: isAlwaysOn)
            }
        case .complete:
            CompleteScreen(
                variant: complete,
                summary: summary ?? workout.summary(at: .now),
                isAlwaysOn: isAlwaysOn,
                done: { stage = .idle }
            )
        }
    }

    private var secondaryPage: some View {
        ControlsPage(
            variant: controls,
            isPaused: (heard ?? workout).isPaused,
            isConnected: isConnected,
            isStopArmed: isStopArmed,
            isAlwaysOn: isAlwaysOn,
            pause: togglePause,
            stop: stopTapped
        )
        .confirmationDialog("End this Workout?", isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button("End Workout", role: .destructive) { finish() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: Actions from the Watch

    private func quickAction() {
        guard isConnected, workout.quickAction(at: .now) else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WKInterfaceDevice.current().play(.success)
        flash = 0.35
        withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
    }

    private func togglePause() {
        guard isConnected else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        workout.togglePause(at: .now)
        WKInterfaceDevice.current().play(.click)
        page = 1
    }

    private func stopTapped() {
        guard isConnected else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        switch stop {
        case .dialog:
            isConfirmingStop = true
        case .tapAgain where isStopArmed:
            finish()
        case .tapAgain:
            isStopArmed = true
            WKInterfaceDevice.current().play(.click)
            Task {
                try? await Task.sleep(for: .seconds(3))
                isStopArmed = false
            }
        }
    }

    private func finish() {
        summary = workout.summary(at: .now)
        heard = nil
        isStopArmed = false
        page = 1
        stage = .complete
        WKInterfaceDevice.current().play(.stop)
    }

    // MARK: Stand-ins for the iPhone

    private func iPhoneStarts(late: Bool) {
        workout = FakeWorkout(type: type, moment: type == .openRounds ? .work : .prepare, now: .now)
        heard = nil
        page = 1
        stage = .waiting(late: late)
        Task {
            // The first message. On the device it took from 1.7 s to 47.6 s.
            try? await Task.sleep(for: .seconds(3))
            guard stage == .waiting(late: late) else { return }
            stage = late ? .late : .running
            WKInterfaceDevice.current().play(.start)
        }
    }

    private func jump() {
        workout = FakeWorkout(type: type, moment: moment.applies(to: type) ? moment : .work, now: .now)
        heard = nil
        page = 1
        stage = .running
    }

    private var connectionBinding: Binding<Bool> {
        Binding(
            get: { isConnected },
            set: { connected in
                // A reconnect sends a fresh full update, which fixes the screen and lifts the dimming.
                heard = connected ? nil : workout
                WKInterfaceDevice.current().play(connected ? .success : .failure)
            }
        )
    }

    // MARK: Prototype controls

    private var prototypeControls: some View {
        NavigationStack {
            List {
                Section("iPhone") {
                    Picker("Workout Type", selection: $type) {
                        ForEach(WorkoutType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Button("Start, in time") { iPhoneStarts(late: false) }
                    Button("Start, Watch late") { iPhoneStarts(late: true) }
                    Toggle("Connected", isOn: connectionBinding)
                    Button("Stop") { finish() }
                    Button("Back to idle") {
                        stage = .idle
                        page = 1
                    }
                }
                Section("Jump into a run") {
                    Picker("At", selection: $moment) {
                        ForEach(Moment.allCases.filter { $0.applies(to: type) }) { Text($0.rawValue).tag($0) }
                    }
                    Button("Go") { jump() }
                }
                Section("Variants") {
                    Picker("Heart rate", selection: $heart) {
                        ForEach(HeartVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Picker("Dropout", selection: $dropout) {
                        ForEach(DropoutVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Picker("Secondary page", selection: $controls) {
                        ForEach(ControlsVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Picker("Stop", selection: $stop) {
                        ForEach(StopVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Picker("Late Watch", selection: $late) {
                        ForEach(LateVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Picker("Complete", selection: $complete) {
                        ForEach(CompleteVariant.allCases) { Text("\($0.rawValue) \($0.name)").tag($0) }
                    }
                    Toggle("Force Always On", isOn: $forcesAlwaysOn)
                }
            }
            .navigationTitle("Prototype")
        }
    }
}
