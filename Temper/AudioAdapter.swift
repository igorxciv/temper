import AVFAudio
import CallKit
import TemperCore
import UIKit

nonisolated enum AudioAdapterError: Error {
    case noCueFormat
    case cueNotRendered
    case noRenderTime
}

/// Carries out what the Cue rules ask for, using a `.playback` session and an engine that renders zeros
/// between Cues. It decides nothing. It reports what iOS does to the session, and makes only the changes
/// that report describes: an engine stopped for a new route, or a new engine after a media-services reset.
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

    /// Route changes that can move output to another device. A category change is the adapter's own Dip.
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
    private let application: UIApplication
    private let clock = ContinuousClock()
    private let session = AVAudioSession.sharedInstance()
    private let calls = CXCallObserver()
    /// Replaced after a media-services reset, because the old one belongs to services that have gone.
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var isGraphBuilt = false
    /// Whether the active session lowers other audio, or `nil` when the session isn't active.
    private var activeDucking: Bool?
    private var sessionObservers: [any NSObjectProtocol] = []

    #if DEBUG
        nonisolated let timingLog = TimingLog()
        private var logObservers: [any NSObjectProtocol] = []
    #endif

    init(cues: CueBank, application: UIApplication) {
        self.cues = cues
        self.application = application
        (events, eventSender) = AsyncStream.makeStream()
    }

    isolated deinit {
        for observer in sessionObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        #if DEBUG
            for observer in logObservers {
                NotificationCenter.default.removeObserver(observer)
            }
        #endif
    }

    // MARK: AudioOutput

    func activate(ducking: Bool) throws {
        observeSessionIfNeeded()
        log("activate", ["duck": ducking, "was_active": activeDucking != nil])
        switch activeDucking {
        case ducking:
            try startAudio()
        case nil:
            try setCategory(ducking: ducking)
            try session.setActive(true)
            activeDucking = ducking
            try startAudio()
        default:
            try cycleSession(ducking: ducking)
        }
    }

    func deactivate() throws {
        stopAudio()
        activeDucking = nil
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func schedule(_ cue: Cue, at deadline: ContinuousClock.Instant, token: CueToken) throws {
        guard let buffer = cues.buffer(for: cue) else {
            log("cue_skipped", ["reason": "not_rendered"])
            throw AudioAdapterError.cueNotRendered
        }
        try startAudio()
        let (nodeTime, playerTime) = try waitForRenderTime()

        let rate = playerTime.sampleRate
        // The deadline is when the Cue leaves the player. Output latency is logged but never subtracted, so when
        // a Cue is heard over Bluetooth is best effort, and AirPlay is unsupported for timing.
        let remaining = Self.seconds(clock.now.duration(to: deadline))
        let target = AVAudioTime.seconds(forHostTime: mach_absolute_time()) + remaining
        let renderHost = AVAudioTime.seconds(forHostTime: nodeTime.hostTime)
        let soonest = playerTime.sampleTime + AVAudioFramePosition(0.02 * rate)
        let sample = max(soonest, playerTime.sampleTime + AVAudioFramePosition((target - renderHost) * rate))

        player.scheduleBuffer(
            buffer,
            at: AVAudioTime(sampleTime: sample, atRate: rate),
            options: [],
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.cueFinished(token, sender: eventSender)
        )

        #if DEBUG
            timingLog.calibrate(hostSeconds: AVAudioTime.seconds(forHostTime: mach_absolute_time()))
            timingLog.setCueTarget(timingLog.wall + remaining)
            logClock(nodeTime)
            log(
                "schedule",
                [
                    "cue": "\(cue)",
                    "lead_ms": remaining * 1000,
                    "output_latency_ms": session.outputLatency * 1000,
                    "io_buffer_ms": session.ioBufferDuration * 1000,
                    "sample_rate": session.sampleRate,
                ]
            )
        #endif
    }

    func cancel() throws {
        guard isGraphBuilt else { return }
        player.stop()
        #if DEBUG
            timingLog.setCueTarget(nil)
            log("cue_cancelled")
        #endif
        if engine.isRunning {
            try player.playAudio()
        }
    }

    /// A call that hasn't ended is ringing, connected or on hold.
    func isOnCall() -> Bool {
        calls.calls.contains { !$0.hasEnded }
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
        guard activeDucking != nil else { return }
        stopAudio()
        activeDucking = nil
        send(.interrupted)
    }

    /// The engine stops here, and the next activate starts it on the new route. An engine that stops itself
    /// for a configuration change isn't reported, because every schedule starts a stopped engine anyway, and
    /// reporting it could loop if a restart caused another change.
    private func routeChanged() {
        guard activeDucking != nil else { return }
        stopAudio()
        #if DEBUG
            logRoute("restart")
        #endif
        send(.routeChanged)
    }

    /// The session's category and the engine went with the old media services. The rendered Cues are plain
    /// memory in the Cue bank, so they stay.
    private func rebuildAfterReset() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        isGraphBuilt = false
        activeDucking = nil
        send(.mediaServicesReset)
    }

    private func send(_ event: AudioEvent) {
        log("audio_event", ["event": "\(event)"])
        eventSender.yield(event)
    }

    // MARK: Session and engine

    private func setCategory(ducking: Bool) throws {
        try session.setCategory(.playback, mode: .default, options: ducking ? [.duckOthers] : [.mixWithOthers])
    }

    /// Dip. Changing the option on an active session doesn't reach other audio, so the session goes down and
    /// comes back. A background task covers the gap, when nothing else is keeping a locked phone's app running.
    /// Notifying on deactivation is what lets other audio return.
    private func cycleSession(ducking: Bool) throws {
        let begin = clock.now
        let backgroundTask = application.beginBackgroundTask(withName: "Dip", expirationHandler: nil)
        defer { application.endBackgroundTask(backgroundTask) }

        stopAudio()
        activeDucking = nil
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        try setCategory(ducking: ducking)
        try session.setActive(true)
        activeDucking = ducking
        try startAudio()

        log("dip_cycle", ["duck": ducking, "ms": Self.seconds(begin.duration(to: clock.now)) * 1000])
    }

    private func buildGraphIfNeeded() throws {
        guard !isGraphBuilt else { return }
        guard let format = CueBank.format else { throw AudioAdapterError.noCueFormat }
        engine.attach(player)
        try engine.connectNode(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        isGraphBuilt = true
        #if DEBUG
            for observer in logObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            logRunStart()
            logRoute("start")
            // The iOS 27.2 SDK has only this underscored form of the call that replaces the deprecated
            // `installTap(onBus:bufferSize:format:block:)`.
            try player.__installTap(
                onBus: 0,
                bufferSize: 1024,
                format: nil,
                error: (),
                block: Self.onsetTap(log: timingLog)
            )
            logObservers = Self.observeForLog(engine: engine, log: timingLog)
        #endif
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
        log("cue_skipped", ["reason": "no_render_time"])
        throw AudioAdapterError.noRenderTime
    }

    private nonisolated static func seconds(_ duration: Duration) -> Double {
        duration / .seconds(1)
    }

    /// Nonisolated, because the player calls this on its own thread.
    private nonisolated static func cueFinished(
        _ token: CueToken,
        sender: AsyncStream<AudioEvent>.Continuation
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { _ in sender.yield(.cueFinished(token)) }
    }

    // MARK: Timing log

    private func log(_ kind: String, _ fields: @autoclosure () -> [String: any Sendable] = [:]) {
        #if DEBUG
            timingLog.write(kind, fields())
        #endif
    }
}

#if DEBUG
    extension AudioAdapter {
        fileprivate func logRunStart() {
            timingLog.write(
                "run_start",
                [
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "cue_render_s": cues.renderSeconds ?? -1,
                ]
            )
        }

        fileprivate func logRoute(_ context: String) {
            Self.logRoute(context, session: session, log: timingLog)
        }

        /// Reads the audio clock against the host clock, so the analyzer can measure drift across a Cue's lead.
        fileprivate func logClock(_ time: AVAudioTime) {
            Self.logClock("lead", time: time, log: timingLog)
        }

        fileprivate nonisolated static func logClock(_ context: String, time: AVAudioTime, log: TimingLog) {
            log.write(
                "clock",
                [
                    "context": context,
                    "host_s": AVAudioTime.seconds(forHostTime: mach_absolute_time()),
                    "render_sample": Int(time.sampleTime),
                    "render_rate": time.sampleRate,
                    "render_host_s": AVAudioTime.seconds(forHostTime: time.hostTime),
                ]
            )
        }

        /// Port types only. A port's name can contain a person's name.
        fileprivate nonisolated static func logRoute(_ context: String, session: AVAudioSession, log: TimingLog) {
            log.write(
                "route",
                [
                    "context": context,
                    "outputs": session.currentRoute.outputs.map(\.portType.rawValue),
                    "output_latency_ms": session.outputLatency * 1000,
                ]
            )
        }

        /// Logs the moment a Cue's first audible sample leaves the player.
        fileprivate nonisolated static func onsetTap(log: TimingLog)
            -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void
        {
            nonisolated(unsafe) var wasSilent = true
            return { buffer, time in
                guard let samples = buffer.floatChannelData?[0] else { return }
                let first = (0..<Int(buffer.frameLength)).first { abs(samples[$0]) > 0.001 }
                if let first, wasSilent, time.isHostTimeValid {
                    let host =
                        AVAudioTime.seconds(forHostTime: time.hostTime) + Double(first) / buffer.format.sampleRate
                    log.recordOnset(wall: log.wall(forHostSeconds: host))
                    if time.isSampleTimeValid {
                        logClock("boundary", time: time, log: log)
                    }
                }
                wasSilent = first == nil
            }
        }

        fileprivate nonisolated static func observeForLog(
            engine: AVAudioEngine,
            log: TimingLog
        ) -> [any NSObjectProtocol] {
            let center = NotificationCenter.default
            let session = AVAudioSession.sharedInstance()
            return [
                center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: nil) {
                    note in
                    let context =
                        note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
                    log.write(
                        "session_inactive",
                        [
                            "source": context?.source.rawValue ?? -1,
                            "interrupted": context?.interruptionContext != nil,
                            "reason": context?.interruptionContext?.reason.rawValue ?? -1,
                        ]
                    )
                },
                center.addObserver(forName: AVAudioSession.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                    log.write("session_active")
                },
                center.addObserver(
                    forName: AVAudioSession.resumptionRecommendationNotification,
                    object: nil,
                    queue: nil
                ) { note in
                    let context =
                        note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
                    log.write("resume_recommendation", ["recommendation": context?.recommendation.rawValue ?? -1])
                },
                center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil)
                { _ in
                    log.write("media_services_reset")
                },
                center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { note in
                    let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 999
                    log.write("route_change", ["reason": Int(reason)])
                    logRoute("route_change", session: session, log: log)
                },
                center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { _ in
                    log.write("engine_config_change", ["running": engine.isRunning])
                },
            ]
        }
    }
#endif
