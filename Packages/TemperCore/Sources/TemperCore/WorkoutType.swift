/// The kind of Workout picked before Start, which decides its shape and its values.
///
/// The raw value is what's remembered as the last-used Workout Type, and it names the type's Presets and, for every
/// type but Intervals, its remembered values, so renaming a case forgets them.
public nonisolated enum WorkoutType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    /// A Prepare, then Rounds of Work and Rest, then a Cooldown.
    case intervals
    /// A Prepare, then a single Work that counts up to a set length.
    case stopwatch
    /// A Prepare, then Rounds of an open Work and a Rest, repeated until Stop.
    case openRounds

    public var id: Self { self }

    /// The Workout Type whose Health workouts are filed under this activity type. Each activity type belongs to
    /// exactly one Workout Type, so this undoes `HealthRecord.ActivityType(_:)`.
    public init(filedAs activityType: HealthRecord.ActivityType) {
        switch activityType {
        case .highIntensityIntervalTraining: self = .intervals
        case .other: self = .stopwatch
        case .traditionalStrengthTraining: self = .openRounds
        }
    }

    /// The name on its tab and its setup screen.
    public var title: String {
        switch self {
        case .intervals: "Intervals"
        case .stopwatch: "Stopwatch"
        case .openRounds: "Open Rounds"
        }
    }

    /// The SF Symbol on its tab.
    public var systemImage: String {
        switch self {
        case .intervals: "repeat"
        case .stopwatch: "stopwatch"
        case .openRounds: "dumbbell"
        }
    }

    /// The values its setup shows, top to bottom. A Workout Type reads only these from its settings.
    public var values: [WorkoutValue] {
        switch self {
        case .intervals: [.prepare, .rounds, .work, .rest, .cooldown]
        case .stopwatch: [.prepare, .work]
        case .openRounds: [.prepare, .rest]
        }
    }

    /// Its values before the owner has changed anything.
    public var firstLaunch: WorkoutSettings {
        switch self {
        case .intervals:
            WorkoutSettings(
                prepare: .seconds(10),
                rounds: 8,
                work: .seconds(40),
                rest: .seconds(20),
                cooldown: .seconds(60)
            )
        case .stopwatch:
            // Only Prepare and Work are read. The rest are placeholders that build a valid Intervals Workout.
            WorkoutSettings(prepare: .seconds(10), rounds: 1, work: .seconds(600), rest: .zero, cooldown: .zero)
        case .openRounds:
            // Only Prepare and Rest are read. Work is open, so its value is never used. Prepare starts Off, so
            // Start goes straight into Work until the owner sets one.
            WorkoutSettings(prepare: .zero, rounds: 1, work: .zero, rest: .seconds(60), cooldown: .zero)
        }
    }

    /// The built-in Plan its values describe, leaving out any zero Prepare, Rest or Cooldown.
    ///
    /// Intervals is a Prepare, then Rounds of Work and Rest with no Rest after the last Work, then a Cooldown. A
    /// Stopwatch is a Prepare, then one Work with no Round that runs past its set length. Open Rounds is a Prepare,
    /// then Rounds of an open Work and a Rest until Stop, and its Rest says "10 seconds" before it ends.
    public func plan(from settings: WorkoutSettings) -> Plan {
        let prepare = Self.leavingOutOff([PlannedPhase(kind: .prepare, duration: settings.prepare)])
            .map(Plan.Block.phase)
        let activity = HealthRecord.ActivityType(self)
        switch self {
        case .intervals:
            let round = [
                PlannedPhase(kind: .work, duration: settings.work),
                PlannedPhase(kind: .rest, duration: settings.rest),
            ]
            let cooldown = Self.leavingOutOff([PlannedPhase(kind: .cooldown, duration: settings.cooldown)])
                .map(Plan.Block.phase)
            return Plan(
                activity: activity,
                blocks: prepare + [.rounds(.times(settings.rounds), Self.leavingOutOff(round))] + cooldown
            )
        case .stopwatch:
            let work = PlannedPhase(kind: .work, length: .runsPast(settings.work))
            return Plan(activity: activity, blocks: prepare + [.phase(work)])
        case .openRounds:
            let round = [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: settings.rest)]
            return Plan(
                activity: activity,
                blocks: prepare + [.rounds(.untilStop, Self.leavingOutOff(round))],
                warnsBeforeRestEnds: true
            )
        }
    }

    /// The Workout its built-in Plan makes. Setup's wheels keep every value in range, so the Plan always makes one.
    public func makeWorkout(from settings: WorkoutSettings) -> Workout {
        do {
            return try plan(from: settings).makeWorkout()
        } catch {
            preconditionFailure("Setup's values make a Workout, not \(error)")
        }
    }

    private static func leavingOutOff(_ phases: [PlannedPhase]) -> [PlannedPhase] {
        phases.filter { $0.length != .set(.zero) }
    }
}
