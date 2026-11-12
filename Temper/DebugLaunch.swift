#if DEBUG
    import Foundation
    import TemperCore

    /// Launch arguments that open a screen at launch, so the Simulator can show every screen with no taps:
    /// `-debugRoute plans|describe|settings|intervals|stopwatch|openRounds` opens a screen over Plans, and
    /// `-debugStart intervals|stopwatch|openRounds|complete|roundsComplete` starts a Workout, the last two short ones
    /// that end on their complete screens.
    @MainActor
    enum DebugLaunch {
        static func apply(runner: WorkoutRunner, remembered: RememberedValues) {
            let defaults = UserDefaults.standard
            switch defaults.string(forKey: "debugRoute") {
            case "plans"?: remembered.path = []
            case "describe"?: remembered.path = [.describe]
            case "settings"?: remembered.path = [.settings]
            case let name?: if let workoutType = WorkoutType(rawValue: name) { remembered.path = [.plan(workoutType)] }
            case nil: break
            }
            guard let start = defaults.string(forKey: "debugStart") else { return }
            if let workoutType = WorkoutType(rawValue: start) {
                runner.start(
                    workoutType.makeWorkout(from: remembered[workoutType]),
                    filedAs: HealthRecord.ActivityType(workoutType), isDipOn: false)
            } else if start == "complete" {
                let plan = Plan(
                    activity: .highIntensityIntervalTraining,
                    blocks: [.rounds(.times(2), [PlannedPhase(kind: .work, duration: .seconds(5))])])
                if let workout = try? plan.makeWorkout() {
                    runner.start(workout, filedAs: .highIntensityIntervalTraining, isDipOn: false)
                }
            } else if start == "roundsComplete" {
                runner.start(
                    WorkoutType.openRounds.makeWorkout(from: WorkoutType.openRounds.firstLaunch),
                    filedAs: .traditionalStrengthTraining, isDipOn: false)
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    runner.done()
                    try? await Task.sleep(for: .seconds(1))
                    runner.stop()
                }
            }
        }
    }
#endif
