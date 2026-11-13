#if DEBUG
    import Foundation
    import TemperCore

    /// Launch arguments that open a screen at launch, so the Simulator can show every screen with no taps:
    /// `-debugTab intervals|stopwatch|openRounds|describe|settings` selects a tab, and
    /// `-debugStart intervals|stopwatch|openRounds|openRoundsRest|planComplete|roundsComplete` starts a Workout:
    /// `openRoundsRest` ends its first Work after 4 seconds, so it shows the Rest after an open Work, and the last two
    /// are short ones that end on their complete screens. It returns the Plan of the Workout it started, for the complete screen.
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
            guard let start = defaults.string(forKey: "debugStart") else { return nil }
            if let workoutType = WorkoutType(rawValue: start) {
                runner.start(
                    workoutType.makeWorkout(from: remembered[workoutType]),
                    filedAs: HealthRecord.ActivityType(workoutType), isDipOn: false)
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
                    runner.start(workout, filedAs: .highIntensityIntervalTraining, isDipOn: false)
                }
                return PlanBoard(plan: plan)
            } else if start == "openRoundsRest" {
                runner.start(
                    WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch),
                    filedAs: .traditionalStrengthTraining, isDipOn: false)
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    runner.done()
                }
                return PlanBoard(workoutType: .openRounds, settings: WorkoutType.openRounds.firstLaunch)
            } else if start == "roundsComplete" {
                runner.start(
                    WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch),
                    filedAs: .traditionalStrengthTraining, isDipOn: false)
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
    }
#endif
