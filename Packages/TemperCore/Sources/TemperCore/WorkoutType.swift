/// The kind of Workout picked before Start, which decides its shape and its values.
///
/// The raw value is what's remembered as the last-used Workout Type, so renaming a case forgets it.
public nonisolated enum WorkoutType: String, CaseIterable, Hashable, Identifiable, Sendable {
    /// A Prepare, then Rounds of Work and Rest, then a Cooldown.
    case intervals
    /// A Prepare, then a single Work that counts up to a set length.
    case stopwatch

    public var id: Self { self }

    /// The name on its tab and its setup screen.
    public var title: String {
        switch self {
        case .intervals: "Intervals"
        case .stopwatch: "Stopwatch"
        }
    }

    /// The SF Symbol on its tab.
    public var systemImage: String {
        switch self {
        case .intervals: "repeat"
        case .stopwatch: "stopwatch"
        }
    }

    /// The values its setup shows, top to bottom. A Workout Type reads only these from its settings.
    public var values: [WorkoutValue] {
        switch self {
        case .intervals: [.prepare, .rounds, .work, .rest, .cooldown]
        case .stopwatch: [.prepare, .work]
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
        }
    }

    /// Builds the Phases in order, dropping any zero Prepare, Rest or Cooldown.
    ///
    /// Intervals is a Prepare, then each Round's Work and Rest with no Rest after the last Work, then a Cooldown.
    /// A Stopwatch is a Prepare, then one Work with no Round.
    public func makeWorkout(from settings: WorkoutSettings) -> Workout {
        precondition(settings.work > .zero, "A Workout always has a Work")
        var phases = [Phase(kind: .prepare, duration: settings.prepare)]
        switch self {
        case .intervals:
            precondition(settings.rounds > 0, "Intervals has at least one Round")
            for round in 1...settings.rounds {
                phases.append(Phase(kind: .work, duration: settings.work, round: round))
                if round < settings.rounds {
                    phases.append(Phase(kind: .rest, duration: settings.rest, round: round))
                }
            }
            phases.append(Phase(kind: .cooldown, duration: settings.cooldown))
        case .stopwatch:
            phases.append(Phase(kind: .work, duration: settings.work))
        }
        return Workout(phases: phases.filter { $0.length != .set(.zero) })
    }
}
