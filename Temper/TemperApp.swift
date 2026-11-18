import SwiftUI
import TemperCore

@main
struct TemperApp: App {
    @State private var runner: WorkoutRunner
    @State private var remembered = RememberedValues()
    @State private var health = HealthAccess()
    @State private var musicLowering: MusicLowering
    @State private var secondsWheel = SecondsWheel()
    @State private var roundSound: RoundSoundSetting
    @State private var tipJar = TipJar()

    init() {
        let musicLowering = MusicLowering()
        _musicLowering = State(initialValue: musicLowering)
        let roundSound = RoundSoundSetting()
        _roundSound = State(initialValue: roundSound)
        let runner = WorkoutRunner(musicLowering: musicLowering, roundSound: roundSound)
        _runner = State(initialValue: runner)
        // The Live Activity's Pause, Resume and Done run in this process, and may be what launched it, so the
        // runner is set before any of them can run.
        LiveActivityControls.workout = runner
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                runner: runner, remembered: remembered, health: health, musicLowering: musicLowering,
                secondsWheel: secondsWheel, roundSound: roundSound, tipJar: tipJar)
        }
    }
}

/// Shows the screen for where the Workout is, and catches up whenever Temper returns to the front.
///
/// The running and complete screens replace the whole tab bar, so nothing on screen distracts from the time.
struct RootView: View {
    let runner: WorkoutRunner
    @Bindable var remembered: RememberedValues
    let health: HealthAccess
    let musicLowering: MusicLowering
    let secondsWheel: SecondsWheel
    let roundSound: RoundSoundSetting
    let tipJar: TipJar

    /// The Plan the Workout was started from, for the complete screen's recap, or `nil` if it isn't known, as after a
    /// relaunch mid-Workout.
    @State private var ranBoard: PlanBoard?
    /// The last Phase that ran, whose color the complete screen's ring closes in.
    @State private var lastPhase: Phase.Kind?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let snapshot = runner.snapshot {
                let display = RunningDisplay(workout: runner.workout, snapshot: snapshot)
                if let phase = snapshot.phase {
                    RunningScreen(
                        display: display,
                        phase: phase,
                        pause: runner.pause,
                        resume: runner.resume,
                        done: runner.done,
                        stop: runner.stop
                    )
                } else {
                    // The runner keeps only an ended snapshot with a complete screen.
                    switch display.completion {
                    case .rounds(let summary):
                        RoundsCompleteScreen(summary: summary, lastPhase: lastPhase ?? finalPhase, close: close)
                    case .total(let total):
                        CompleteScreen(board: ranBoard, total: total, lastPhase: lastPhase ?? finalPhase, close: close)
                    case nil:
                        EmptyView()
                    }
                }
            } else {
                // The system Liquid Glass tab bar, with no background of its own.
                TabView(selection: $remembered.selectedTab) {
                    ForEach(RootTab.workoutTypes) { workoutType in
                        Tab(
                            workoutType.title, systemImage: workoutType.systemImage,
                            value: RootTab.workoutType(workoutType)
                        ) {
                            NavigationStack {
                                SetupScreen(
                                    workoutType: workoutType, remembered: remembered, secondsWheel: secondsWheel
                                ) { workoutType, workout in
                                    ranBoard = PlanBoard(workoutType: workoutType, settings: remembered[workoutType])
                                    runner.start(workout, runningAs: ActivityType(workoutType))
                                }
                            }
                        }
                    }
                    Tab("Describe", systemImage: "text.bubble", value: RootTab.describe) {
                        NavigationStack {
                            DescribeScreen(remembered: remembered) { workout, activityType in
                                ranBoard = remembered.describedPlan.map(PlanBoard.init(plan:))
                                runner.start(workout, runningAs: activityType)
                            }
                        }
                    }
                    Tab("Settings", systemImage: "gearshape", value: RootTab.settings) {
                        NavigationStack {
                            SettingsScreen(
                                health: health, musicLowering: musicLowering, secondsWheel: secondsWheel,
                                roundSound: roundSound, tipJar: tipJar)
                        }
                    }
                }
                // Dragging the setup rows scrolls, and the tabs stay in view through it.
                .tabBarMinimizeBehavior(.never)
                .tint(InkColors(contrast: contrast).accent)
            }
        }
        .fontDesign(.rounded)
        // From launch, so a tip approved or interrupted while Temper was away is finished without opening Settings.
        .task { await tipJar.observeTransactionUpdates() }
        .onChange(of: runner.snapshot?.phase?.kind, initial: true) { _, kind in
            if let kind {
                lastPhase = kind
            }
        }
        #if DEBUG
            .task {
                if let board = DebugLaunch.apply(runner: runner, remembered: remembered) {
                    ranBoard = board
                }
            }
        #endif
        .onChange(of: roundSound.sound) {
            runner.roundSoundChanged()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                runner.refresh()
            }
        }
    }

    /// The Workout's final Phase, for a complete screen opened with no last Phase seen, as after a relaunch.
    private var finalPhase: Phase.Kind? {
        (runner.workout.phases + runner.workout.repeatingRound).last?.kind
    }

    private func close() {
        ranBoard = nil
        lastPhase = nil
        runner.finish()
    }
}
