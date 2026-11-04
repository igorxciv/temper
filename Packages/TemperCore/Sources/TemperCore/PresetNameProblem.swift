/// Why a Preset can't take a name. A name check reports the first of these, in this order.
public nonisolated enum PresetNameProblem: Error, Equatable, Sendable {
    /// Nothing is left once the name is trimmed.
    case empty
    /// The trimmed name has more than 30 characters, so it wouldn't fit under setup's title.
    case tooLong
    /// Another Preset of the same Workout Type already has this name, ignoring case.
    case taken(existingName: String, workoutType: WorkoutType)

    /// The longest name, counted in `Character`s, so an emoji counts as one.
    public static let maximumLength = 30

    /// The line under the name sheet's field. An empty name needs none, as for any empty field.
    public var footer: String? {
        switch self {
        case .empty: nil
        case .tooLong: "Names are \(Self.maximumLength) characters at most."
        case .taken(let existingName, let workoutType):
            "Another \(workoutType.title) Preset is called “\(existingName)”."
        }
    }
}
