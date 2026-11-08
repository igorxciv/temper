// PROBE, throwaway. The Watch side of the link. It owns the workout session: `handle(_:)` makes it, `prepare()`,
// and only at `.prepared` does it mirror (Apple DTS's workaround for the iOS 26 bug), then `startActivity`. It
// pings every 5 s, sends taps, shows heart rate, and saves to Health when the session stops from either side.

import Foundation
import HealthKit
import Observation
import WatchKit

@Observable
final class WatchProbe: NSObject {
    static let shared = WatchProbe()

    let log = ProbeLog(side: "watch")
    let store = HKHealthStore()

    private(set) var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private(set) var state: HKWorkoutSessionState?
    private(set) var isMirroring = false
    private(set) var heartRate: Double?
    private(set) var stats = LinkStats()
    /// The stand-in Phase's start, on the iPhone's clock.
    private(set) var phaseStart: Date?
    private(set) var steps: [Wire.Step] = []
    private(set) var lastTap = "–"
    private(set) var healthStatus = "not asked"

    private var pingID = 0
    private var tapID = 0
    private var openTaps: [Int: Date] = [:]
    private var heartbeat: Task<Void, Never>?
    /// Log lines waiting for a mirrored session to carry them to the iPhone.
    private var unsent: [Wire] = []

    override init() {
        super.init()
        log.add("launched")
        refreshHealthStatus()
    }

    // MARK: Health

    func askForHealth() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        store.requestAuthorization(toShare: share, read: read) { [weak self] success, error in
            Task { @MainActor in
                self?.refreshHealthStatus()
                self?.note("Health request: \(success) \(error.map { "\($0)" } ?? "")")
            }
        }
    }

    func refreshHealthStatus() {
        healthStatus = "workouts \(store.authorizationStatus(for: HKObjectType.workoutType()).label)"
    }

    // MARK: Session

    /// Called from `WKApplicationDelegate.handle(_:)`, after the iPhone's `startWatchApp`.
    func handle(_ configuration: HKWorkoutConfiguration, at date: Date) {
        steps = []
        step("handle(_:)", at: date)
        if let session, session.state != .ended {
            note("handle(_:) while a session is \(session.state.label); ending it first")
            session.end()
        }
        refreshHealthStatus()
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            stats = LinkStats()
            phaseStart = nil
            session.prepare()
            step("prepare() called")
        } catch {
            note("session not created: \(error)")
        }
    }

    /// Called from `handleActiveWorkoutRecovery()` after a crash.
    func recover() {
        note("recovering an active session")
        store.recoverActiveWorkoutSession { [weak self] session, error in
            let handed = session.map { Handed(value: $0) }
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                guard let session = handed?.value else { return self.note("recovery failed: \(text ?? "no session")") }
                session.delegate = self
                let builder = session.associatedWorkoutBuilder()
                builder.delegate = self
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.store, workoutConfiguration: session.workoutConfiguration)
                self.session = session
                self.builder = builder
                self.state = session.state
                self.note("recovered, state \(session.state.label)")
            }
        }
    }

    private func prepared() {
        guard let session else { return }
        step("prepared")
        session.startMirroringToCompanionDevice { [weak self] success, error in
            let at = Date.now
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.step("mirroring started", at: at)
                    self.mirroringStarted()
                } else {
                    self.note("mirroring failed: \(text ?? "no error")")
                }
                self.startActivity()
            }
        }
    }

    private func startActivity() {
        guard let session, let builder, session.state == .prepared else { return }
        let start = Date.now
        session.startActivity(with: start)
        builder.addMetadata(["TemperProbe": "watch-link-probe"]) { _, _ in }
        builder.beginCollection(withStart: start) { [weak self] success, error in
            let text = error.map { "\($0)" }
            Task { @MainActor in
                self?.note("collection began: \(success) \(text ?? "")")
            }
        }
        step("startActivity called", at: start)
    }

    private func mirroringStarted() {
        isMirroring = true
        if stats.connectedSince == nil { stats.connectedSince = .now }
        send(.hello(steps: steps))
        let backlog = unsent
        unsent = []
        for line in backlog { send(line) }
        startHeartbeat()
    }

    func stopMirroring() {
        guard let session else { return }
        note("stopMirroringToCompanionDevice")
        isMirroring = false
        session.stopMirroringToCompanionDevice { [weak self] success, error in
            let text = error.map { "\($0)" }
            Task { @MainActor in self?.note("mirroring stopped: \(success) \(text ?? "")") }
        }
    }

    func mirrorAgain() {
        guard let session else { return }
        note("startMirroringToCompanionDevice again")
        session.startMirroringToCompanionDevice { [weak self] success, error in
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                self.note("mirroring again: \(success) \(text ?? "")")
                if success { self.mirroringStarted() }
            }
        }
    }

    /// Ends from the Watch, as the Stop page would.
    func stop() {
        guard let session else { return }
        note("stopActivity(with: now) on the Watch")
        session.stopActivity(with: .now)
    }

    private func stopped(at date: Date) {
        guard let session, let builder else { return }
        builder.endCollection(withEnd: date) { [weak self] _, error in
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                if let text { self.note("endCollection failed: \(text)") }
                builder.finishWorkout { workout, error in
                    let line =
                        workout.map {
                            "saved workout \($0.uuid.uuidString.prefix(8)), \(Int($0.duration)) s, "
                                + "\($0.allStatistics.count) statistics"
                        } ?? "workout not saved: \(error.map { "\($0)" } ?? "no error")"
                    Task { @MainActor in
                        self.note(line)
                        session.end()
                    }
                }
            }
        }
    }

    private func ended() {
        heartbeat?.cancel()
        heartbeat = nil
        isMirroring = false
        note("ended. \(stats.summary)")
    }

    // MARK: Link

    private func startHeartbeat() {
        guard heartbeat == nil else { return }
        heartbeat = Task {
            while !Task.isCancelled {
                pingID += 1
                stats.pingsSent += 1
                send(.ping(id: pingID, at: .now, heartRate: heartRate))
                if stats.pingsSent % 12 == 0 { note("link: \(stats.summary)") }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func tap() {
        guard session != nil else {
            WKInterfaceDevice.current().play(.failure)
            lastTap = "no session"
            return
        }
        tapID += 1
        let id = tapID
        let at = Date.now
        openTaps[id] = at
        WKInterfaceDevice.current().play(.click)
        send(.tap(id: id, at: at))
        lastTap = "#\(id) sent"
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard openTaps.removeValue(forKey: id) != nil else { return }
            lastTap = "#\(id) LOST"
            WKInterfaceDevice.current().play(.failure)
            note("tap #\(id): no answer in 2 s")
        }
    }

    private func send(_ wire: Wire) {
        guard let session else { return }
        session.sendToRemoteWorkoutSession(data: wire.encoded()) { [weak self] success, error in
            guard !success else { return }
            let text = error.map { "\($0)" } ?? "no error"
            Task { @MainActor in
                guard let self else { return }
                self.stats.sendFailures += 1
                // Not forwarded: it would fail the same way.
                self.log.add("send failed: \(text)")
            }
        }
    }

    private func received(_ wire: Wire, at date: Date) {
        stats.lastHeard = date
        switch wire {
        case .phase(let startedAt):
            phaseStart = startedAt
        case .tapAck(let id, _):
            guard let sentAt = openTaps.removeValue(forKey: id) else { return }
            let roundTrip = date.timeIntervalSince(sentAt)
            lastTap = "#\(id) back in \(ms(roundTrip))"
            note("tap #\(id) acknowledged, round trip \(ms(roundTrip))")
        case .ping(let id, let at, _):
            stats.pingsReceived += 1
            send(.pong(id: id, pingAt: at, at: .now))
        case .pong(_, let pingAt, let at):
            stats.record(ClockSample(pingAt: pingAt, theirReplyAt: at, receivedAt: date))
        case .hello, .tap, .log:
            break
        }
    }

    // MARK: Log

    private func step(_ name: String, at date: Date = .now) {
        steps.append(Wire.Step(name: name, at: date))
        note(name, at: date)
    }

    /// Logs here and forwards the line to the iPhone, holding it until a mirrored session exists.
    private func note(_ text: String, at date: Date = .now) {
        log.add(text, at: date)
        let wire = Wire.log(line: text, at: date)
        if isMirroring {
            send(wire)
        } else if unsent.count < 200 {
            unsent.append(wire)
        }
    }

    private func stateChanged(
        _ id: ObjectIdentifier, to new: HKWorkoutSessionState, from old: HKWorkoutSessionState, at date: Date
    ) {
        guard session.map(ObjectIdentifier.init) == id else { return }
        note("state \(old.label) → \(new.label)", at: date)
        state = new
        switch new {
        case .prepared: prepared()
        case .running: step("running", at: date)
        case .stopped: stopped(at: date)
        case .ended: ended()
        default: break
        }
    }
}

extension WatchProbe: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in self.stateChanged(id, to: toState, from: fromState, at: date) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let text = "\(error)"
        Task { @MainActor in self.note("session failed: \(text)") }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        let text = error.map { "\($0)" } ?? "no error"
        Task { @MainActor in
            self.isMirroring = false
            self.note("DISCONNECTED from the iPhone: \(text)")
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

extension WatchProbe: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate),
            let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()
        else { return }
        let bpm = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        Task { @MainActor in self.heartRate = bpm }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
