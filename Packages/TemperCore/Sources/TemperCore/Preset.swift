import Foundation

/// A named, saved set of one Workout Type's values, kept for starting that kind of Workout again.
///
/// Its identity is separate from its name, so renaming it keeps it picked.
public nonisolated struct Preset: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var settings: WorkoutSettings

    public init(id: UUID = UUID(), name: String, settings: WorkoutSettings) {
        self.id = id
        self.name = name
        self.settings = settings
    }
}
