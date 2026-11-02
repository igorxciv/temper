// PROTOTYPE, throw away. Runs a Workout with the researched design and logs what happens.
// Time comes only from ContinuousClock offsets from one anchor. Nothing is counted.
import AVFAudio
import CallKit
import UIKit

private final class CallWatcher: NSObject, CXCallObserverDelegate, @unchecked Sendable {
    let observer = CXCallObserver()
    let log: RunLog
    init(log: RunLog) {
        self.log = log
        super.init()
        observer.setDelegate(self, queue: nil)
    }
    var inCall: Bool { observer.calls.contains { !$0.hasEnded } }
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        log.write(
            "call",
            ["connected": call.hasConnected, "ended": call.hasEnded, "outgoing": call.isOutgoing])
    }
}

private final class SynthWatcher: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let log: RunLog
    init(log: RunLog) { self.log = log }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance
    ) {
        log.recordOnset(wall: log.wall)
    }
}

actor Probe {
    private let config: RunConfig
    private let log: RunLog
    private let cues: CueBank
    private let clock = ContinuousClock()
    private let session = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let quiet = AVAudioPlayerNode()
    private let calls: CallWatcher
    private let synthWatcher: SynthWatcher
    private let synth = AVSpeechSynthesizer()

    private var anchor: ContinuousClock.Instant
    private var frozen: Duration?
    private var stopped = false
    private var sleeper: Task<Void, Error>?
    private var resumeWaiter: CheckedContinuation<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var pending: (word: String, deadline: ContinuousClock.Instant)?
    private var observers: [any NSObjectProtocol] = []

    init(config: RunConfig, log: RunLog, cues: CueBank) {
        self.config = config
        self.log = log
        self.cues = cues
        calls = CallWatcher(log: log)
        synthWatcher = SynthWatcher(log: log)
        anchor = ContinuousClock.now
    }

    // MARK: Workout

    func run() async {
        synth.delegate = synthWatcher
        synth.usesApplicationAudioSession = false
        log.write(
            "run_start",
            [
                "preset": config.preset.rawValue, "keep_alive": config.keepAlive.rawValue,
                "dip": config.dip.rawValue,
                "compensate": config.compensateLatency, "heartbeat": config.heartbeat,
                "note": config.note,
                "model": Self.model(), "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "cue_source_format": cues.sourceFormat, "cue_render_s": cues.renderSeconds,
                "cue_seconds": cues.buffers.mapValues {
                    Double($0.frameLength) / $0.format.sampleRate
                },
            ])
        observe()
        do {
            try setCategory(duck: false)
            try session.setActive(true)
            try buildGraph()
            try startAudio()
            logRoute("start")
        } catch {
            log.write("setup_failed", ["error": "\(error)"])
            log.setFinished()
            return
        }
        if config.keepAlive == .sessionOnly { stopAudio() }
        startHeartbeat()

        let phases = config.preset.phases
        var offset = Duration.zero
        anchor = clock.now
        log.write("anchor")
        for index in phases.indices {
            let phase = phases[index]
            log.setPhase(phase.name, endsAt: anchor + offset + .seconds(phase.seconds))
            offset += .seconds(phase.seconds)
            let isLast = index == phases.count - 1
            let word = isLast ? "Workout complete" : phases[index + 1].name
            let next = isLast ? nil : phases[index + 1]
            await reachBoundary(at: offset, word: word, phaseIndex: index, next: next)
            if stopped { break }
        }
        finish(completed: !stopped)
    }

    private func reachBoundary(
        at boundary: Duration, word: String, phaseIndex: Int, next: ProbePhase?
    ) async {
        while !stopped {
            let lead = min(config.dip.lead, boundary)
            _ = await waitActive(until: boundary - lead)
            if stopped { return }
            logClock("lead")
            let skip = await prepareCue(word: word, boundary: boundary)
            let interrupted = await waitActive(until: boundary)
            if stopped { return }
            if interrupted {
                log.write("cue_cancelled_by_pause", ["word": word])
                await cancelCue()
                continue
            }
            let lateMs = RunLog.seconds((anchor + boundary).duration(to: clock.now)) * 1000
            log.recordPhaseLate(ms: lateMs)
            log.write(
                "phase_end",
                [
                    "index": phaseIndex, "next": word, "late_ms": lateMs,
                    "boundary_s": RunLog.seconds(boundary),
                ])
            if let next {
                log.setPhase(next.name, endsAt: anchor + boundary + .seconds(next.seconds))
            }
            logClock("boundary")
            if !skip {
                if config.dip == .synthSession { speakLive(word) }
                await finishCue(word: word)
            }
            return
        }
    }

    /// Returns true when a Pause happened while waiting.
    private func waitActive(until target: Duration) async -> Bool {
        var interrupted = false
        while !stopped {
            if frozen != nil {
                interrupted = true
                await withCheckedContinuation { resumeWaiter = $0 }
                continue
            }
            let deadline = anchor + target
            if clock.now >= deadline { return interrupted }
            let sleepClock = clock
            let task = Task<Void, Error> {
                try await sleepClock.sleep(until: deadline, tolerance: .milliseconds(10))
            }
            sleeper = task
            _ = try? await task.value
            sleeper = nil
        }
        return interrupted
    }

    func pause() {
        guard frozen == nil, !stopped else { return }
        frozen = anchor.duration(to: clock.now)
        sleeper?.cancel()
        log.write("pause", ["active_s": RunLog.seconds(frozen ?? .zero)])
        log.setPaused(remaining: .zero)
    }

    func resume() {
        guard let held = frozen else { return }
        anchor = clock.now - held
        frozen = nil
        log.write("resume", ["active_s": RunLog.seconds(held)])
        resumeWaiter?.resume()
        resumeWaiter = nil
    }

    func stop() {
        stopped = true
        sleeper?.cancel()
        resumeWaiter?.resume()
        resumeWaiter = nil
        log.write("stop")
    }

    private func finish(completed: Bool) {
        heartbeatTask?.cancel()
        stopAudio()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.write("deactivate_failed", ["error": "\(error)"])
        }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        log.write(
            "run_end",
            ["completed": completed, "active_s": RunLog.seconds(anchor.duration(to: clock.now))])
        log.setFinished()
        log.close()
    }

    // MARK: Cues

    /// Returns true if this Cue will be skipped.
    private func prepareCue(word: String, boundary: Duration) async -> Bool {
        if calls.inCall {
            log.write("cue_skipped", ["word": word, "reason": "in_call"])
            log.recordSkip()
            return true
        }
        do {
            switch config.dip {
            case .off, .synthSession:
                try session.setActive(true)
                if config.keepAlive == .sessionOnly || !engine.isRunning { try startAudio() }
            case .sessionCycle:
                try await cycleSession(duck: true)
            case .optionToggle:
                let begin = clock.now
                try setCategory(duck: true)
                log.write(
                    "dip_toggle",
                    ["duck": true, "ms": RunLog.seconds(begin.duration(to: clock.now)) * 1000])
                if !engine.isRunning { try startAudio() }
            }
        } catch {
            log.write("cue_skipped", ["word": word, "reason": "activation", "error": "\(error)"])
            log.recordSkip()
            return true
        }
        if config.dip != .synthSession {
            pending = (word, anchor + boundary)
            await scheduleCue(word: word, deadline: anchor + boundary)
        } else {
            log.setCueTarget(
                RunLog.seconds(anchor.advanced(by: boundary).duration(to: clock.now)) * -1
                    + log.wall)
        }
        return false
    }

    private func scheduleCue(word: String, deadline: ContinuousClock.Instant) async {
        guard let buffer = cues.buffers[word] else {
            log.write("cue_missing", ["word": word])
            return
        }
        var waitedMs = 0
        while player.lastRenderTime == nil && waitedMs < 1000 {
            try? await clock.sleep(for: .milliseconds(10), tolerance: .milliseconds(2))
            waitedMs += 10
        }
        guard let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid,
            nodeTime.isHostTimeValid,
            let playerTime = player.playerTime(forNodeTime: nodeTime)
        else {
            log.write(
                "cue_skipped", ["word": word, "reason": "no_render_time", "waited_ms": waitedMs])
            log.recordSkip()
            return
        }
        let rate = playerTime.sampleRate
        let hostNow = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        let remaining = RunLog.seconds(clock.now.duration(to: deadline))
        if remaining < -0.25 {
            log.write("cue_skipped", ["word": word, "reason": "overdue", "overdue_s": -remaining])
            log.recordSkip()
            return
        }
        let renderHost = AVAudioTime.seconds(forHostTime: nodeTime.hostTime)
        let latency = config.compensateLatency ? session.outputLatency : 0
        let targetHost = hostNow + remaining - latency
        var sample = playerTime.sampleTime + AVAudioFramePosition((targetHost - renderHost) * rate)
        let late = sample <= playerTime.sampleTime
        if late { sample = playerTime.sampleTime + AVAudioFramePosition(0.02 * rate) }
        let at = AVAudioTime(sampleTime: sample, atRate: rate)
        log.calibrate()
        log.setCueTarget(log.wall + remaining)
        player.scheduleBuffer(buffer, at: at, options: [], completionHandler: nil)
        log.write(
            "schedule",
            [
                "word": word, "lead_ms": remaining * 1000, "late": late, "render_wait_ms": waitedMs,
                "output_latency_ms": session.outputLatency * 1000,
                "io_buffer_ms": session.ioBufferDuration * 1000,
                "sample_rate": session.sampleRate,
            ])
    }

    private func speakLive(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        log.write("speak_call", ["word": word])
        synth.speak(utterance)
    }

    private func finishCue(word: String) async {
        pending = nil
        let length = cues.buffers[word].map { Double($0.frameLength) / $0.format.sampleRate } ?? 1
        try? await clock.sleep(for: .seconds(length + 0.3), tolerance: .milliseconds(10))
        do {
            switch config.dip {
            case .sessionCycle: try await cycleSession(duck: false)
            case .optionToggle:
                let begin = clock.now
                try setCategory(duck: false)
                log.write(
                    "dip_toggle",
                    ["duck": false, "ms": RunLog.seconds(begin.duration(to: clock.now)) * 1000])
            case .off, .synthSession: break
            }
            if config.keepAlive == .sessionOnly { stopAudio() }
        } catch {
            log.write("dip_restore_failed", ["error": "\(error)"])
        }
    }

    private func cancelCue() async {
        pending = nil
        log.setCueTarget(nil)
        player.stop()
        do {
            try player.playAudio()
            switch config.dip {
            case .sessionCycle: try await cycleSession(duck: false)
            case .optionToggle: try setCategory(duck: false)
            case .off, .synthSession: break
            }
        } catch {
            log.write("dip_restore_failed", ["error": "\(error)"])
        }
    }

    // MARK: Audio session and engine

    private func setCategory(duck: Bool) throws {
        try session.setCategory(
            .playback, mode: .default, options: duck ? [.duckOthers] : [.mixWithOthers])
    }

    /// Variant A. A background task covers the gap while the session is inactive.
    private func cycleSession(duck: Bool) async throws {
        let begin = clock.now
        let task = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "dip", expirationHandler: nil)
        }
        defer { Task { @MainActor in UIApplication.shared.endBackgroundTask(task) } }
        stopAudio()
        try session.setActive(false)
        try setCategory(duck: duck)
        try session.setActive(true)
        if config.keepAlive != .sessionOnly || duck { try startAudio() }
        log.write(
            "dip_cycle", ["duck": duck, "ms": RunLog.seconds(begin.duration(to: clock.now)) * 1000])
    }

    private func buildGraph() throws {
        guard let format = cues.format else { return }
        engine.attach(player)
        engine.attach(quiet)
        try engine.connectNode(player, to: engine.mainMixerNode, format: format)
        try engine.connectNode(quiet, to: engine.mainMixerNode, format: format)
        engine.prepare()
        let log = self.log
        player.installTap(onBus: 0, bufferSize: 1024, format: nil, block: Self.onsetTap(log: log))
    }

    /// Logs the moment the Cue's first audible sample leaves the player node.
    private nonisolated static func onsetTap(log: RunLog)
        -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void
    {
        nonisolated(unsafe) var wasSilent = true
        return { buffer, when in
            guard let samples = buffer.floatChannelData?[0] else { return }
            var first: Int?
            for index in 0..<Int(buffer.frameLength) where abs(samples[index]) > 0.001 {
                first = index
                break
            }
            if let first, wasSilent, when.isHostTimeValid {
                let host =
                    AVAudioTime.seconds(forHostTime: when.hostTime) + Double(first)
                    / buffer.format.sampleRate
                log.recordOnset(wall: log.wall(forHostSeconds: host))
            }
            wasSilent = first == nil
        }
    }

    private func startAudio() throws {
        if !engine.isRunning { try engine.start() }
        try player.playAudio()
        if config.keepAlive == .quiet, let format = cues.format,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate))
        {
            buffer.frameLength = buffer.frameCapacity
            if let samples = buffer.floatChannelData?[0] {
                for index in 0..<Int(buffer.frameLength) {
                    samples[index] = index % 2 == 0 ? 0.0001 : -0.0001
                }
            }
            quiet.stop()
            quiet.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            try quiet.playAudio()
        }
    }

    private func stopAudio() {
        player.stop()
        quiet.stop()
        engine.stop()
    }

    /// Brings the session and engine back after an interruption, so the app has a reason to keep running.
    func recover(_ trigger: String) async {
        guard !stopped else { return }
        do {
            try session.setActive(true)
            if config.keepAlive != .sessionOnly || pending != nil { try startAudio() }
            log.write("recovered", ["trigger": trigger, "engine_running": engine.isRunning])
            if let pending { await scheduleCue(word: pending.word, deadline: pending.deadline) }
        } catch {
            log.write("recover_failed", ["trigger": trigger, "error": "\(error)"])
        }
    }

    private func restartAfterConfigChange() async {
        log.write("engine_config_change", ["running": engine.isRunning])
        logRoute("config_change")
        guard !stopped, config.keepAlive != .sessionOnly || pending != nil else { return }
        do {
            try startAudio()
            if let pending { await scheduleCue(word: pending.word, deadline: pending.deadline) }
        } catch {
            log.write("engine_restart_failed", ["error": "\(error)"])
        }
    }

    // MARK: Observation

    private func observe() {
        let center = NotificationCenter.default
        let log = self.log
        let add = {
            (name: Notification.Name, handler: @escaping @Sendable (Notification) -> Void) in
            center.addObserver(forName: name, object: nil, queue: nil, using: handler)
        }
        observers.append(
            add(AVAudioSession.didBecomeInactiveNotification) { note in
                let context =
                    note.userInfo?[AVAudioSession.deactivationContextKey]
                    as? AVAudioSession.DeactivationContext
                log.write(
                    "session_inactive",
                    [
                        "source": context?.source.rawValue ?? -1,
                        "interrupted": context?.interruptionContext != nil,
                        "reason": context?.interruptionContext?.reason.rawValue ?? -1,
                    ])
            })
        observers.append(
            add(AVAudioSession.didBecomeActiveNotification) { _ in log.write("session_active") })
        observers.append(
            add(AVAudioSession.resumptionRecommendationNotification) { [weak self] note in
                let context =
                    note.userInfo?[AVAudioSession.resumptionContextKey]
                    as? AVAudioSession.ResumptionContext
                log.write(
                    "resume_recommendation",
                    ["recommendation": context?.recommendation.rawValue ?? -1])
                Task { await self?.recover("resume_recommendation") }
            })
        observers.append(
            add(AVAudioSession.mediaServicesWereResetNotification) { _ in
                log.write("media_services_reset")
            })
        observers.append(
            add(AVAudioSession.routeChangeNotification) { [weak self] note in
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 999
                log.write("route_change", ["reason": Int(reason)])
                Task { await self?.logRoute("route_change") }
            })
        observers.append(
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
            ) { [weak self] _ in
                Task { await self?.restartAfterConfigChange() }
            })
    }

    /// Port types only. Port names can contain a person's name.
    private func logRoute(_ context: String) {
        log.write(
            "route",
            [
                "context": context,
                "outputs": session.currentRoute.outputs.map(\.portType.rawValue),
                "output_latency_ms": session.outputLatency * 1000,
            ])
    }

    private func logClock(_ context: String) {
        log.calibrate()
        var fields: [String: any Sendable] = [
            "context": context, "host_s": AVAudioTime.seconds(forHostTime: mach_absolute_time()),
        ]
        if let time = player.lastRenderTime, time.isSampleTimeValid, time.isHostTimeValid {
            fields["render_sample"] = Int(time.sampleTime)
            fields["render_rate"] = time.sampleRate
            fields["render_host_s"] = AVAudioTime.seconds(forHostTime: time.hostTime)
        }
        log.write("clock", fields)
    }

    private func startHeartbeat() {
        guard config.heartbeat else { return }
        let log = self.log
        let beatClock = clock
        heartbeatTask = Task.detached {
            var next = beatClock.now
            while !Task.isCancelled {
                next += .seconds(1)
                try? await beatClock.sleep(until: next, tolerance: .milliseconds(100))
                let late = RunLog.seconds(next.duration(to: beatClock.now))
                if late > 0.25 { log.write("heartbeat_late", ["late_s": late]) }
            }
        }
    }

    private static func model() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) {
            String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
        }
    }
}
