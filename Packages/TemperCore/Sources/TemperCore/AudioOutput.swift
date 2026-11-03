/// Tells one armed Cue from another, so a late answer about an old Cue is never taken for the current one.
public nonisolated struct CueToken: Hashable, Sendable {
    let value: Int
}

/// What the audio side reports on its own, outside any call.
public nonisolated enum AudioEvent: Equatable, Sendable {
    case interrupted
    case resumeRecommended
    case routeChanged
    case mediaServicesReset
    /// The Cue armed with this token has finished speaking.
    case cueFinished(CueToken)
}

/// The only way from the Cue rules to audio. Calls may take a while and may fail, and the Cue rules decide
/// what to do about either, so an implementation carries out each call in the order it arrives and decides
/// nothing itself.
public nonisolated protocol AudioOutput<Instant>: Sendable {
    associatedtype Instant: InstantProtocol

    /// Has one consumer, the Cue rules.
    var events: AsyncStream<AudioEvent> { get }

    /// Activates the session, or changes whether it lowers other audio if it's already active.
    func activate(ducking: Bool) async throws
    /// Releases the session, so other audio returns to full volume.
    func deactivate() async throws
    /// Arranges for a Cue to start speaking at `deadline`, or at once if that has passed. Returns when it's
    /// arranged, not when it has played.
    func schedule(_ cue: Cue, at deadline: Instant, token: CueToken) async throws
    /// Cuts any Cue that's speaking or waiting to speak.
    func cancel() async throws
}
