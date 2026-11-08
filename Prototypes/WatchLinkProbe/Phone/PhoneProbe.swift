// PROBE, throwaway. The iPhone side of the link: starts the Watch app with `startWatchApp`, times the mirrored
// session's arrival, pings every 5 s, beeps on each Watch tap, and ends the session from this side on request.

import Foundation
import HealthKit
import Observation

@Observable
final class PhoneProbe: NSObject {
    /// The cases the ticket asks for. Picked before each Start so the log says which run is which.
    static let cases = [
        "awake, Bluetooth", "awake, Wi-Fi", "wrist down", "cold launch (Watch restarted)", "Watch off",
        "Watch off wrist", "locked 10 min", "30 min soak", "force-quit iPhone", "other",
    ]

    let log = ProbeLog(side: "phone")
    let store = HKHealthStore()
    private let beeper = Beeper()

    var caseName = cases[0]
    var healthStatus = "not asked"
    private(set) var session: HKWorkoutSession?
    private(set) var state: HKWorkoutSessionState?
    private(set) var instances = 0
    private(set) var startedAt: Date?
    private(set) var completion: String?
    private(set) var mirroredAfter: TimeInterval?
    private(set) var stats = LinkStats()
    private(set) var phaseStart: Date?
    private(set) var watchHeartRate: Double?
    private(set) var taps = 0
    private(set) var lastTap: TimeInterval?
    private(set) var maxTap: TimeInterval = 0
    private(set) var watchSteps: [Wire.Step] = []
    var isAudioRunning: Bool { beeper.isRunning }

    private var pingID = 0
    private var heartbeat: Task<Void, Never>?
    private var phaseTimer: Task<Void, Never>?

    override init() {
        super.init()
        beeper.onEvent = { [weak self] in self?.log.add($0) }
        // Set promptly at launch: HealthKit may launch this app in the background to hand over a session.
        store.workoutSessionMirroringStartHandler = { [weak self] session in
            let at = Date.now
            let handed = Handed(value: session)
            Task { @MainActor in self?.mirrored(handed.value, at: at) }
        }
        log.add("launched, mirroring handler set")
    }

    // MARK: Health

    func askForHealth() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate)]
        store.requestAuthorization(toShare: share, read: read) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                let status = self.store.authorizationStatus(for: HKObjectType.workoutType())
                self.healthStatus = "workouts \(status.label)"
                self.log.add("Health request: \(success) \(error.map { "\($0)" } ?? ""), workouts \(status.label)")
            }
        }
    }

    func refreshHealthStatus() {
        healthStatus = "workouts \(store.authorizationStatus(for: HKObjectType.workoutType()).label)"
    }

    // MARK: Start

    func start() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .highIntensityIntervalTraining
        configuration.locationType = .indoor
        let calledAt = Date.now
        startedAt = calledAt
        completion = nil
        mirroredAfter = nil
        watchSteps = []
        beeper.start()
        log.add("=== case: \(caseName) ===")
        log.add("startWatchApp called")
        store.startWatchApp(with: configuration) { [weak self] success, error in
            let at = Date.now
            let text =
                "\(secs(at.timeIntervalSince(calledAt))) \(success ? "success" : "failure")"
                + (error.map { " \($0.localizedDescription)" } ?? "")
            Task { @MainActor in
                guard let self, self.startedAt == calledAt else { return }
                self.completion = text
                self.log.add("startWatchApp completion after \(text)")
            }
        }
        Task {
            for mark in [10, 30, 60] {
                try? await Task.sleep(for: .seconds(Double(mark) - Date.now.timeIntervalSince(calledAt)))
                guard startedAt == calledAt, mirroredAfter == nil else { return }
                log.add("no mirrored session \(mark) s after startWatchApp")
            }
        }
    }

    // MARK: Mirrored session

    private func mirrored(_ session: HKWorkoutSession, at date: Date) {
        instances += 1
        session.delegate = self
        let replaced = self.session != nil
        self.session = session
        state = session.state
        var line = "mirrored session #\(instances) arrived, state \(session.state.label)"
        if let startedAt, mirroredAfter == nil {
            let after = date.timeIntervalSince(startedAt)
            mirroredAfter = after
            line += ", \(secs(after)) after startWatchApp"
        } else {
            line += replaced ? ", replacing an earlier instance" : ", without a Start in this launch"
        }
        log.add(line, at: date)
        if stats.connectedSince == nil { stats.connectedSince = date }
        startPhases()
        startHeartbeat()
    }

    private func startPhases() {
        guard phaseTimer == nil else {
            if let phaseStart { send(.phase(startedAt: phaseStart)) }
            return
        }
        let start = Date.now
        phaseStart = start
        send(.phase(startedAt: start))
        phaseTimer = Task {
            var next = start
            while !Task.isCancelled {
                next += phaseLength
                try? await Task.sleep(for: .seconds(next.timeIntervalSinceNow))
                guard !Task.isCancelled else { return }
                phaseStart = next
                send(.phase(startedAt: next))
            }
        }
    }

    private func startHeartbeat() {
        guard heartbeat == nil else { return }
        heartbeat = Task {
            while !Task.isCancelled {
                ping()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func ping() {
        pingID += 1
        stats.pingsSent += 1
        send(.ping(id: pingID, at: .now, heartRate: nil))
        if stats.pingsSent % 12 == 0 { log.add("link: \(stats.summary)") }
    }

    private func send(_ wire: Wire) {
        guard let session else { return }
        session.sendToRemoteWorkoutSession(data: wire.encoded()) { [weak self] success, error in
            guard !success else { return }
            let text = error.map { "\($0)" } ?? "no error"
            Task { @MainActor in
                self?.stats.sendFailures += 1
                self?.log.add("send failed: \(text)")
            }
        }
    }

    private func received(_ wire: Wire, at date: Date) {
        stats.lastHeard = date
        switch wire {
        case .hello(let steps):
            watchSteps = steps
            for step in steps {
                log.add("watch step: \(step.name) at \(ProbeLog.time(step.at)) (watch clock)", at: date)
            }
        case .tap(let id, let at):
            beeper.play()
            taps += 1
            send(.tapAck(id: id, at: date))
            var line = "tap #\(id) arrived, beep scheduled"
            if let best = stats.best {
                // The tap's Watch time, moved onto this clock.
                let latency = date.timeIntervalSince(at) + best.theirsAhead
                lastTap = latency
                maxTap = max(maxTap, latency)
                line += ", Watch→iPhone \(ms(latency))"
            }
            log.add(line + (isAudioRunning ? "" : ", AUDIO NOT RUNNING"), at: date)
        case .ping(let id, let at, let heartRate):
            stats.pingsReceived += 1
            watchHeartRate = heartRate
            send(.pong(id: id, pingAt: at, at: .now))
        case .pong(_, let pingAt, let at):
            stats.record(ClockSample(pingAt: pingAt, theirReplyAt: at, receivedAt: date))
        case .log(let line, let at):
            log.add(line, at: at, from: "watch")
        case .tapAck, .phase:
            break
        }
    }

    // MARK: Ending from this side

    func stopActivity() {
        guard let session else { return log.add("stopActivity: no session") }
        log.add("stopActivity(with: now) on the mirrored session")
        session.stopActivity(with: .now)
    }

    func end() {
        guard let session else { return log.add("end: no session") }
        log.add("end() on the mirrored session")
        session.end()
    }

    func stopAudio() {
        beeper.stop()
    }

    func logSummary() {
        var parts = ["summary (\(caseName)):", stats.summary]
        if let mirroredAfter { parts.append("mirrored after \(secs(mirroredAfter))") }
        if let completion { parts.append("completion \(completion)") }
        if taps > 0 { parts.append("\(taps) taps, last \(lastTap.map(ms) ?? "?"), max \(ms(maxTap))") }
        parts.append("instances \(instances)")
        log.add(parts.joined(separator: " "))
    }

    private func sessionGone() {
        heartbeat?.cancel()
        heartbeat = nil
        phaseTimer?.cancel()
        phaseTimer = nil
        logSummary()
        stats = LinkStats()
        session = nil
    }

    private func stateChanged(
        _ id: ObjectIdentifier, to new: HKWorkoutSessionState, from old: HKWorkoutSessionState, at date: Date
    ) {
        let current = session.map(ObjectIdentifier.init) == id
        log.add("state \(old.label) → \(new.label)\(current ? "" : " (stale instance)")", at: date)
        guard current else { return }
        state = new
        if new == .ended { sessionGone() }
    }
}

extension PhoneProbe: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        let id = ObjectIdentifier(workoutSession)
        let at = Date.now
        Task { @MainActor in self.stateChanged(id, to: toState, from: fromState, at: at) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let at = Date.now
        let text = "\(error)"
        Task { @MainActor in self.log.add("session failed: \(text)", at: at) }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        let at = Date.now
        let text = error.map { "\($0)" } ?? "no error"
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in
            let current = self.session.map(ObjectIdentifier.init) == id
            self.log.add("DISCONNECTED from the Watch\(current ? "" : " (stale instance)"): \(text)", at: at)
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        let at = Date.now
        let messages = data.compactMap(Wire.decode)
        Task { @MainActor in
            for message in messages { self.received(message, at: at) }
        }
    }
}
