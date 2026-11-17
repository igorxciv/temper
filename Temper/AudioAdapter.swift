import AVFAudio
import CallKit
import TemperCore

nonisolated enum AudioAdapterError: Error {
    case noCueFormat
    case cueNotRendered
    case noRenderTime
    case tooLate
}

/// Carries out what the Cue rules ask for, using a `.playback` session that mixes with other audio, and an engine
/// that renders zeros between Cues. It decides nothing. It reports what iOS does to the session, and makes only the
/// changes that report describes: an engine stopped for a new route, or a new engine after a media-services reset.
///
/// A Cue the rules say lowers other audio adds `.duckOthers` to the live session, and it comes off once every such
/// Cue has played or been cut. The session stays active throughout, because deactivating it between Cues would stop
/// the engine that keeps the app running while locked. Changing the options posts a category change, which isn't
/// taken for a new route.
///
/// One adapter serves one Workout. All adapters share one queue and never suspend inside a call, so calls run
/// strictly in the order they arrive, even a new Workout's activate right after the last one's deactivate.
/// Session calls block for hundreds of milliseconds, so the queue also keeps them off the shared thread pool.
/// Notifications are handled on the same queue, in the order iOS posts them.
///
/// Running while locked rests only on this session and the `audio` background mode, so it's best effort. There
/// is no notification fallback, because notification sounds obey Silent mode and Cues must not.
actor AudioAdapter: AudioOutput {
    private static let queue = DispatchSerialQueue(label: "Temper.audio", qos: .userInteractive)

    /// Route changes that can move output to another device. A category change is the adapter's own.
    private static let newRouteReasons: Set<AVAudioSession.RouteChangeReason> = [
        .newDeviceAvailable, .oldDeviceUnavailable, .override, .wakeFromSleep, .noSuitableRouteForCategory,
        .routeConfigurationChange,
    ]

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        Self.queue.asUnownedSerialExecutor()
    }

    nonisolated let events: AsyncStream<AudioEvent>
    private nonisolated let eventSender: AsyncStream<AudioEvent>.Continuation

    private let cues: CueBank
    private let clock = ContinuousClock()
    private let session = AVAudioSession.sharedInstance()
    private let calls = CXCallObserver()
    /// Replaced after a media-services reset, because the old one belongs to services that have gone.
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var isGraphBuilt = false
    private var isActive = false
    /// The Cues lowering other audio that haven't finished. Other audio stays lowered while any remain, because the
    /// next Cue is handed over while the one before is still speaking.
    private var loweringCues: Set<CueToken> = []
    private var isLoweringOthers = false
    private var sessionObservers: [any NSObjectProtocol] = []

    init(cues: CueBank) {
        self.cues = cues
        (events, eventSender) = AsyncStream.makeStream()
    }

    isolated deinit {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: AudioOutput

    func activate() throws {
        observeSessionIfNeeded()
        if !isActive {
            forgetLowering()
            try session.setCategory(.playback, mode: .default, options: Self.mixing)
            try session.setActive(true)
            isActive = true
        }
        try startAudio()
    }

    func deactivate() throws {
        stopAudio()
        forgetLowering()
        isActive = false
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// A Cue whose Exercise isn't rendered yet plays plain, so the Phase change is still heard. A Prepare's start
    /// says only its Exercise, so then there's nothing to play: it ends at once, quietly, rather than as a failure
    /// that would let go of the session.
    ///
    /// Other audio is lowered before the engine starts and the Cue is placed, in case the option change stops the
    /// engine, since starting it again would lose a Cue already placed.
    func schedule(
        _ cue: Cue,
        saying exercise: Exercise?,
        at deadline: ContinuousClock.Instant,
        startingBy latest: ContinuousClock.Instant,
        lowersOtherAudio: Bool,
        token: CueToken
    ) throws {
        guard let buffer = cues.buffer(for: cue, saying: exercise) ?? cues.buffer(for: cue) else {
            guard cue != .prepare else {
                eventSender.yield(.cueFinished(token))
                return
            }
            throw AudioAdapterError.cueNotRendered
        }
        if lowersOtherAudio {
            lowerOtherAudio(for: token)
        }
        do {
            try play(buffer, at: deadline, startingBy: latest, token: token)
        } catch {
            stopLowering(for: token)
            throw error
        }
    }

    func cancel() throws {
        guard isGraphBuilt else { return }
        player.stop()
        raiseOtherAudio()
        if engine.isRunning {
            try player.playAudio()
        }
    }

    /// A call that hasn't ended is ringing, connected or on hold.
    func isOnCall() -> Bool {
        calls.calls.contains { !$0.hasEnded }
    }

    private func play(
        _ buffer: AVAudioPCMBuffer,
        at deadline: ContinuousClock.Instant,
        startingBy latest: ContinuousClock.Instant,
        token: CueToken
    ) throws {
        try startAudio()
        let (nodeTime, playerTime) = try waitForRenderTime()

        let rate = playerTime.sampleRate
        // The deadline is when the Cue leaves the player. Output latency is never subtracted, so when a Cue is
        // heard over Bluetooth is best effort, and AirPlay is unsupported for timing.
        let now = clock.now
        let hostNow = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        let remaining = Self.seconds(now.duration(to: deadline))
        let target = hostNow + remaining
        let renderHost = AVAudioTime.seconds(forHostTime: nodeTime.hostTime)
        let soonest = playerTime.sampleTime + AVAudioFramePosition(0.02 * rate)
        let sample = max(soonest, playerTime.sampleTime + AVAudioFramePosition((target - renderHost) * rate))

        let start = renderHost + Double(sample - playerTime.sampleTime) / rate
        guard start <= hostNow + Self.seconds(now.duration(to: latest)) else {
            throw AudioAdapterError.tooLate
        }

        player.scheduleBuffer(
            buffer,
            at: AVAudioTime(sampleTime: sample, atRate: rate),
            options: [],
            completionCallbackType: .dataPlayedBack,
            completionHandler: cueFinished(token)
        )
    }

    // MARK: Lowering other audio

    private static let mixing: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// Best effort: a Cue that can't lower other audio still plays.
    private func lowerOtherAudio(for token: CueToken) {
        loweringCues.insert(token)
        guard isActive, !isLoweringOthers else { return }
        if (try? session.setCategory(.playback, mode: .default, options: Self.mixing.union(.duckOthers))) != nil {
            isLoweringOthers = true
        }
    }

    /// Raises other audio once the last Cue lowering it has finished. A token it doesn't hold belongs to a Cue that
    /// didn't lower, or one already cut, so it changes nothing.
    private func stopLowering(for token: CueToken) {
        guard loweringCues.remove(token) != nil, loweringCues.isEmpty else { return }
        raiseOtherAudio()
    }

    private func raiseOtherAudio() {
        loweringCues = []
        guard isLoweringOthers else { return }
        if (try? session.setCategory(.playback, mode: .default, options: Self.mixing)) != nil {
            isLoweringOthers = false
        }
    }

    /// For a session that's inactive or about to be set up again, which no longer lowers anything.
    private func forgetLowering() {
        loweringCues = []
        isLoweringOthers = false
    }

    // MARK: What iOS does to the session

    private func observeSessionIfNeeded() {
        guard sessionObservers.isEmpty else { return }
        let center = NotificationCenter.default
        sessionObservers = [
            center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: nil) {
                [weak self] note in
                let context =
                    note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
                guard context?.source == .system else { return }
                self?.onQueue { $0.sessionWasTaken() }
            },
            center.addObserver(
                forName: AVAudioSession.resumptionRecommendationNotification,
                object: nil,
                queue: nil
            ) { [weak self] note in
                let context = note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
                guard context?.recommendation == .shouldResume else { return }
                self?.onQueue { $0.send(.resumeRecommended) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) {
                [weak self] note in
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                    .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                guard let reason, Self.newRouteReasons.contains(reason) else { return }
                self?.onQueue { $0.routeChanged() }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) {
                [weak self] _ in
                self?.onQueue { $0.rebuildAfterReset() }
            },
        ]
    }

    /// Runs a notification's work on the adapter's queue, after any call already on it.
    private nonisolated func onQueue(_ work: @escaping @Sendable (isolated AudioAdapter) -> Void) {
        Self.queue.async {
            self.assumeIsolated(work)
        }
    }

    /// Only an active session can be taken. iOS has already stopped the engine.
    private func sessionWasTaken() {
        guard isActive else { return }
        stopAudio()
        forgetLowering()
        isActive = false
        send(.interrupted)
    }

    /// The engine stops here, and the next activate starts it on the new route. An engine that stops itself
    /// for a configuration change isn't reported, because every schedule starts a stopped engine anyway, and
    /// reporting it could loop if a restart caused another change.
    private func routeChanged() {
        guard isActive else { return }
        stopAudio()
        send(.routeChanged)
    }

    /// The session's category and the engine went with the old media services. The rendered Cues are plain
    /// memory in the Cue bank, so they stay.
    private func rebuildAfterReset() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        isGraphBuilt = false
        forgetLowering()
        isActive = false
        send(.mediaServicesReset)
    }

    private func send(_ event: AudioEvent) {
        eventSender.yield(event)
    }

    // MARK: Session and engine

    private func buildGraphIfNeeded() throws {
        guard !isGraphBuilt else { return }
        guard let format = CueBank.format else { throw AudioAdapterError.noCueFormat }
        engine.attach(player)
        try engine.connectNode(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isGraphBuilt = true
    }

    private func startAudio() throws {
        try buildGraphIfNeeded()
        if !engine.isRunning {
            try engine.start()
        }
        if !player.isPlaying {
            try player.playAudio()
        }
    }

    private func stopAudio() {
        guard isGraphBuilt else { return }
        player.stop()
        engine.stop()
    }

    /// The engine has no render time for a moment after it starts. This blocks the queue rather than suspending,
    /// because a suspension would let a later call overtake this one. Only other audio calls wait on the queue.
    private func waitForRenderTime() throws -> (node: AVAudioTime, player: AVAudioTime) {
        let limit = clock.now.advanced(by: .seconds(1))
        while clock.now < limit {
            if let node = player.lastRenderTime, node.isSampleTimeValid, node.isHostTimeValid,
                let playerTime = player.playerTime(forNodeTime: node)
            {
                return (node, playerTime)
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw AudioAdapterError.noRenderTime
    }

    private nonisolated static func seconds(_ duration: Duration) -> Double {
        duration / .seconds(1)
    }

    /// Nonisolated, because the player calls this on its own thread. Raising other audio is a session call, so it
    /// waits its turn on the queue.
    private nonisolated func cueFinished(
        _ token: CueToken
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [eventSender, weak self] _ in
            eventSender.yield(.cueFinished(token))
            self?.onQueue { $0.stopLowering(for: token) }
        }
    }
}
