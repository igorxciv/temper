/// The kind of Workout picked before Start, which decides its shape and its values.
///
/// The raw value is what's remembered as the last-used Workout Type, and it names the type's Presets and, for every
/// type but Intervals, its remembered values, so renaming a case forgets them.
public nonisolated enum WorkoutType: String, CaseIterable, Hashable, Identifiable, Sendable {
    /// A Prepare, then Rounds of Work and Rest, then a Cooldown.
    case intervals
    /// A Prepare, then a single Work that counts up to a set length.
    case stopwatch
    /// Rounds of an open Work and a Rest, repeated until Stop.
    case openRounds

    public var id: Self { self }

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
        case .openRounds: [.rest]
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
            // Only Rest is read. Work is open, so its value is never used.
            WorkoutSettings(prepare: .zero, rounds: 1, work: .zero, rest: .seconds(60), cooldown: .zero)
        }
    }

    /// Builds the Phases in order, dropping any zero Prepare, Rest or Cooldown.
    ///
    /// Intervals is a Prepare, then each Round's Work and Rest with no Rest after the last Work, then a Cooldown.
    /// A Stopwatch is a Prepare, then one Work with no Round. Open Rounds is nothing before a repeating Round of an
    /// open Work and a Rest, and its Rest says "10 seconds" before it ends.
    public func makeWorkout(from settings: WorkoutSettings) -> Workout {
        let prepare = Phase(kind: .prepare, duration: settings.prepare)
        switch self {
        case .intervals:
            precondition(settings.work > .zero, "Intervals and Stopwatch always have a Work")
            precondition(settings.rounds > 0, "Intervals has at least one Round")
            var phases = [prepare]
            for round in 1...settings.rounds {
                phases.append(Phase(kind: .work, duration: settings.work, round: round))
                if round < settings.rounds {
                    phases.append(Phase(kind: .rest, duration: settings.rest, round: round))
                }
            }
            phases.append(Phase(kind: .cooldown, duration: settings.cooldown))
            return Workout(phases: Self.droppingZero(phases))
        case .stopwatch:
            precondition(settings.work > .zero, "Intervals and Stopwatch always have a Work")
            return Workout(phases: Self.droppingZero([prepare, Phase(kind: .work, duration: settings.work)]))
        case .openRounds:
            let round = [Phase(kind: .work, length: .open), Phase(kind: .rest, duration: settings.rest)]
            return Workout(phases: [], repeatingRound: Self.droppingZero(round), warnsBeforeRestEnds: true)
        }
    }

    private static func droppingZero(_ phases: [Phase]) -> [Phase] {
        phases.filter { $0.length != .set(.zero) }
    }
}
