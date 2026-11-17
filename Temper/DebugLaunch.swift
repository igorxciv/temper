#if DEBUG
    import Foundation
    import TemperCore

    /// Launch arguments that open a screen at launch, so the Simulator can show every screen with no taps:
    /// `-debugTab intervals|stopwatch|openRounds|describe|settings` selects a tab, and
    /// `-debugStart intervals|stopwatch|openRounds|openRoundsRest|planComplete|roundsComplete` starts a Workout:
    /// `openRoundsRest` ends its first Work after 4 seconds, so it shows the Rest after an open Work, and the last two
    /// are short ones that end on their complete screens. It returns the Plan of the Workout it started, for the complete screen.
    ///
    /// For the App Store screenshots, `-debugDescribe "words"` opens Describe and makes a Plan of the words as Make
    /// Plan does, `-debugStart describe` starts the Plan Describe last made, and `-debugPresets` saves sample Intervals
    /// Presets if there are none.
    @MainActor
    enum DebugLaunch {
        static func apply(runner: WorkoutRunner, remembered: RememberedValues) -> PlanBoard? {
            let defaults = UserDefaults.standard
            switch defaults.string(forKey: "debugTab") {
            case "describe"?: remembered.selectedTab = .describe
            case "settings"?: remembered.selectedTab = .settings
            case let name?:
                if let workoutType = WorkoutType(rawValue: name) { remembered.selectedTab = .workoutType(workoutType) }
            case nil: break
            }
            if defaults.bool(forKey: "debugPresets") {
                savePresets(in: remembered)
            }
            if let words = defaults.string(forKey: "debugDescribe") {
                describe(words, in: remembered)
            }
            guard let start = defaults.string(forKey: "debugStart") else { return nil }
            if start == "describe" {
                guard let plan = remembered.describedPlan, let workout = try? plan.makeWorkout() else { return nil }
                runner.start(workout, runningAs: plan.activity)
                return PlanBoard(plan: plan)
            } else if let workoutType = WorkoutType(rawValue: start) {
                runner.start(
                    workoutType.makeWorkout(from: remembered[workoutType]),
                    runningAs: ActivityType(workoutType))
                return PlanBoard(workoutType: workoutType, settings: remembered[workoutType])
            } else if start == "planComplete" {
                let plan = Plan(
                    activity: .highIntensityIntervalTraining,
                    blocks: [
                        .phase(PlannedPhase(kind: .prepare, duration: .seconds(3))),
                        .rounds(
                            .times(2),
                            [
                                PlannedPhase(kind: .work, duration: .seconds(4)),
                                PlannedPhase(kind: .rest, duration: .seconds(3)),
                            ]),
                        .phase(PlannedPhase(kind: .cooldown, duration: .seconds(3))),
                    ])
                if let workout = try? plan.makeWorkout() {
                    runner.start(workout, runningAs: .highIntensityIntervalTraining)
                }
                return PlanBoard(plan: plan)
            } else if start == "openRoundsRest" {
                runner.start(
                    WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch),
                    runningAs: .traditionalStrengthTraining)
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    runner.done()
                }
                return PlanBoard(workoutType: .openRounds, settings: WorkoutType.openRounds.firstLaunch)
            } else if start == "roundsComplete" {
                runner.start(
                    WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch),
                    runningAs: .traditionalStrengthTraining)
                Task {
                    // Long enough for the first Work to count as a Round, however slowly the launch went.
                    try? await Task.sleep(for: .seconds(4))
                    runner.done()
                    try? await Task.sleep(for: .seconds(1))
                    runner.stop()
                }
            }
            return nil
        }

        /// Three Intervals Presets, the first picked, leaving setup on its values.
        private static func savePresets(in remembered: RememberedValues) {
            guard remembered.presets(of: .intervals).presets.isEmpty else { return }
            let samples = [
                (
                    "Tabata",
                    WorkoutSettings(
                        prepare: .seconds(10), rounds: 8, work: .seconds(20), rest: .seconds(10), cooldown: .zero)
                ),
                (
                    "Boxing",
                    WorkoutSettings(
                        prepare: .seconds(15), rounds: 6, work: .seconds(180), rest: .seconds(60), cooldown: .zero)
                ),
                (
                    "Hill Sprints",
                    WorkoutSettings(
                        prepare: .seconds(30), rounds: 10, work: .seconds(30), rest: .seconds(90),
                        cooldown: .seconds(300))
                ),
            ]
            for (name, settings) in samples {
                remembered[.intervals] = settings
                try? remembered.saveAsNewPreset(named: name, of: .intervals)
            }
            if let first = remembered.presets(of: .intervals).presets.first {
                remembered.pickPreset(first.id, of: .intervals)
            }
        }

        /// Makes a Plan of `words` as Describe's Make Plan does, and opens Describe on it.
        private static func describe(_ words: String, in remembered: RememberedValues) {
            remembered.selectedTab = .describe
            remembered.workoutDescription = words
            Task {
                guard let plan = try? await PlanWriter.draft(for: words).plan, (try? plan.makeWorkout()) != nil else {
                    return
                }
                remembered.describedPlan = plan
                remembered.describedPlanWords = words
            }
        }
    }
#endif
