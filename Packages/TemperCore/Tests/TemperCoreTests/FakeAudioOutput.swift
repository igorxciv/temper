@testable import TemperCore

/// An `AudioOutput` that records every call as it begins and does as a test tells it. It's an actor because
/// the real adapter is, so the Cue rules meet the same suspensions here.
actor FakeAudioOutput: AudioOutput {
    enum Call: Equatable, Sendable {
        case activate(ducking: Bool)
        case deactivate
        case schedule(Cue, at: ManualClock.Instant)
        case cancel
    }

    enum Outcome {
        case succeed, fail
        /// Stays suspended until `release`.
        case hold
    }

    private struct Failure: Error {}

    nonisolated let events: AsyncStream<AudioEvent>
    /// Yields every call as it begins, so a test can wait for one with no real sleep.
    nonisolated let calls: AsyncStream<Call>

    private nonisolated let eventSender: AsyncStream<AudioEvent>.Continuation
    private nonisolated let callSender: AsyncStream<Call>.Continuation

    private var outcomes: [(call: Call, outcome: Outcome)] = []
    private var held: [CheckedContinuation<Void, any Error>] = []

    private(set) var history: [Call] = []
    /// The token of every Cue scheduled so far.
    private(set) var tokens: [CueToken] = []
    /// The latest start allowed for every Cue scheduled so far.
    private(set) var latestStarts: [ManualClock.Instant] = []
    /// A phone call. Checking for one isn't an audio call, so it's left out of `history`.
    private var hasCall = false

    init() {
        (events, eventSender) = AsyncStream.makeStream()
        (calls, callSender) = AsyncStream.makeStream()
    }

    /// Sets how the next matching call ends. Outcomes for a call are used in the order they were set.
    func onNext(_ call: Call, _ outcome: Outcome) {
        outcomes.append((call, outcome))
    }

    /// Ends every held call.
    func release(failing: Bool = false) {
        for call in held {
            if failing {
                call.resume(throwing: Failure())
            } else {
                call.resume()
            }
        }
        held = []
    }

    nonisolated func send(_ event: AudioEvent) {
        eventSender.yield(event)
    }

    /// Reports that the latest scheduled Cue has finished speaking.
    func finishSpeaking() {
        if let token = tokens.last {
            eventSender.yield(.cueFinished(token))
        }
    }

    func activate(ducking: Bool) async throws {
        try await perform(.activate(ducking: ducking))
    }

    func deactivate() async throws {
        try await perform(.deactivate)
    }

    func schedule(
        _ cue: Cue,
        at deadline: ManualClock.Instant,
        startingBy latest: ManualClock.Instant,
        token: CueToken
    ) async throws {
        tokens.append(token)
        latestStarts.append(latest)
        try await perform(.schedule(cue, at: deadline))
    }

    func cancel() async throws {
        try await perform(.cancel)
    }

    func isOnCall() -> Bool {
        hasCall
    }

    /// Starts or ends a phone call.
    func setCall(_ isOn: Bool) {
        hasCall = isOn
    }

    private func perform(_ call: Call) async throws {
        history.append(call)
        callSender.yield(call)
        guard let index = outcomes.firstIndex(where: { $0.call == call }) else { return }
        switch outcomes.remove(at: index).outcome {
        case .succeed:
            return
        case .fail:
            throw Failure()
        case .hold:
            try await withCheckedThrowingContinuation { held.append($0) }
        }
    }
}
