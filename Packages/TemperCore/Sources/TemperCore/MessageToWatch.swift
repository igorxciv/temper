import Foundation

/// What the iPhone sends the Watch over the mirrored workout session, encoded as JSON.
///
/// Every mirrored instance that belongs to the running Workout gets `begin`, then the latest `update`, then `end` once
/// the Workout has ended, so a Watch that connects late or reconnects catches up the same way. There are no
/// acknowledgements: the iPhone sees the Watch's session end through the mirrored session's own state. An update is
/// under 1 KB, far inside the session's limit of 100 KB per 10 s. Only `end` grows with the Workout, and even 200
/// Rounds of Open Rounds stay under half that limit, so nothing throttles.
public nonisolated enum MessageToWatch: Codable, Hashable, Sendable {
    /// The version of these messages. A Watch that gets a `begin` with another version shows "Update Temper" and ends
    /// without saving, and the iPhone's own Health workout covers the Workout. Raise it whenever a message changes
    /// in a way an older build can't read.
    public static let version = 2

    /// The first message to each mirrored instance: which Workout it belongs to, when that Workout started, and
    /// whether the Watch arrived within the 10 s window after the iPhone asked it to open.
    case begin(workoutID: UUID, start: Date, workoutType: WorkoutType, inTime: Bool, version: Int)
    /// What to draw now, sent on every event.
    case update(WatchState)
    /// A tap from the Watch reached the iPhone more than 2 s after the owner made it, so the engine never got it.
    case refused(WatchCommand)
    /// The Workout has ended, with the Health record the iPhone saves, or `nil` for no record.
    case end(HealthRecord?)

    /// Decodes a message from the JSON `json()` made.
    public init(json: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: json)
    }

    /// The message as JSON, for `sendToRemoteWorkoutSession(data:)`.
    public func json() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
