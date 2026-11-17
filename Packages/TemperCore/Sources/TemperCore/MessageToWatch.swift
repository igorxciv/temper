import Foundation

/// What the iPhone sends the Watch over the mirrored workout session, encoded as JSON.
///
/// Every mirrored instance that belongs to the running Workout gets `begin`, then the latest `update`, then `end` once
/// the Workout has ended, so a Watch that connects late or reconnects catches up the same way. An instance that
/// belongs to no running Workout gets `discard` alone. There are no
/// acknowledgements: the iPhone sees the Watch's session end through the mirrored session's own state. A running
/// Phase's update is under 1 KB, far inside the session's limit of 100 KB per 10 s. Only Open Rounds' ended update,
/// with a row per Round, grows with the Workout, and even 200 Rounds stay under half that limit, so nothing
/// throttles.
public nonisolated enum MessageToWatch: Codable, Hashable, Sendable {
    /// The version of these messages. A Watch that gets a `begin` with another version shows "Update Temper" and ends
    /// its session, and the Workout runs on the iPhone alone. Raise it whenever a message changes in a way an older
    /// build can't read, and keep `begin` readable by every earlier version, so that check can happen.
    /// Version 2 added each Phase's Cues. Version 3 added `refused`, with the Watch's taps going the other way.
    /// Version 4 added `begin`'s `savesToHealth`, for a Settings switch that turned saving off. Version 5 dropped the
    /// Health record from `end`, as Temper stopped saving Health workouts altogether. Version 6 added each Phase's
    /// title and next Exercise.
    public static let version = 6

    /// The first message to each mirrored instance: which Workout it belongs to, when that Workout started, and
    /// whether the Watch arrived within the 10 s window after the iPhone asked it to open.
    ///
    /// The Watch no longer reads the Workout Type or `savesToHealth`, which is always `false`. They're still sent
    /// because a Watch on an earlier version needs them to read `begin` at all, and only then sees the version and
    /// shows "Update Temper".
    case begin(
        workoutID: UUID, start: Date, workoutType: WorkoutType, inTime: Bool, savesToHealth: Bool, version: Int)
    /// What to draw now, sent on every event.
    case update(WatchState)
    /// A tap from the Watch reached the iPhone more than 2 s after the owner made it, so the engine never got it.
    case refused(WatchCommand)
    /// The Workout has ended, so the Watch ends its session, saving nothing.
    case end
    /// The session belongs to no running Workout, so the Watch ends it. It needed no new version: a build that can't
    /// read it drops it, and carries on as it did before there was one.
    case discard

    /// Decodes a message from the JSON `json()` made.
    public init(json: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: json)
    }

    /// The message as JSON, for `sendToRemoteWorkoutSession(data:)`.
    public func json() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
