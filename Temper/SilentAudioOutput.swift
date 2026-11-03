import TemperCore

/// Plays nothing and never fails. Every Cue reports finishing as soon as it's scheduled, so the Cue rules
/// lift any Dip and release the session as they would with real audio.
nonisolated struct SilentAudioOutput: AudioOutput {
    let events: AsyncStream<AudioEvent>
    private let eventSender: AsyncStream<AudioEvent>.Continuation

    init() {
        (events, eventSender) = AsyncStream.makeStream()
    }

    func activate(ducking: Bool) async throws {}

    func deactivate() async throws {}

    func schedule(_ cue: Cue, at deadline: ContinuousClock.Instant, token: CueToken) async throws {
        eventSender.yield(.cueFinished(token))
    }

    func cancel() async throws {}
}
