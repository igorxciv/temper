import Foundation

/// What the owner calls the activity of a Work in a Plan, such as Squats.
///
/// It's spoken in the Phase before its Work and shown on every screen that runs the Workout, so it's kept short: trimmed,
/// and cut to `maximumLength` characters. Nothing else limits what it says.
public nonisolated struct Exercise: Hashable, Sendable {
    /// The most characters an Exercise keeps. It fits the Watch's title and the compact Live Activity once cut short,
    /// and is short enough to say in the room a Phase leaves after its own Cue.
    public static let maximumLength = 24

    public let name: String

    /// The Exercise `text` names, trimmed and cut to `maximumLength`, or `nil` if nothing is left.
    public init?(_ text: String) {
        let name = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        self.name = name
    }
}
