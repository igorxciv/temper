// PROBE, throwaway. The iPhone side. Start calls `startWatchApp` for the picked run, drives a stand-in Workout of
// Work 20 s / Rest 10 s, and sends the plan, Phases, Pause, Resume and Stop with its record over the mirrored
// session. For the replacement runs it saves its own workout the way Temper's iPhone save does, with sync version 1:
// before Start in run A, after the Watch saves in run B. It lists every probe workout Health shows it.

import Foundation
import HealthKit
import Observation

@Observable
final class PhoneProbe: NSObject {
    enum Run: String, CaseIterable, Identifiable {
        case plain = "Plain session"
        case replaceA = "A: iPhone v1 first, live activities"
        case replaceB = "B: Watch v1,000,000 first, record activities"
        case rings = "Open Rounds rings, record activities"

        var id: Self { self }

        var activityType: HKWorkoutActivityType {
            self == .rings ? .traditionalStrengthTraining : .highIntensityIntervalTraining
        }

        var activities: ActivityMode {
            switch self {
            case .plain: .none
            case .replaceA: .live
            case .replaceB, .rings: .record
            }
        }

        var syncs: Bool { self == .replaceA || self == .replaceB }
    }

    let log = ProbeLog(side: "phone")
    let store = HKHealthStore()
    private let beeper = Beeper()

    var run = Run.plain
    private(set) var healthStatus = "–"
    private(set) var session: HKWorkoutSession?
    private(set) var state: HKWorkoutSessionState?
    private(set) var completion: String?
    private(set) var mirroredAfter: TimeInterval?
    private(set) var phase: Phase?
    private(set) var isPaused = false
    private(set) var watchHeartRate: Double?
    private(set) var watchUpdates = 0

    private var workoutStart: Date?
    private var runOfStart = Run.plain
    private var syncIdentifier: String?
    private var phases: [Phase] = []
    private var pauses: [Record.Span] = []
    private var pauseStart: Date?
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
        Task { await refreshStatus("launch") }
    }

    // MARK: Health

    func askForHealth() {
        log.add("asking for Health")
        Task {
            do {
                try await store.requestAuthorization(toShare: ProbeHealth.share, read: ProbeHealth.read)
                log.add("Health request returned")
            } catch {
                log.add("Health request failed: \(error)")
            }
            await refreshStatus("after asking")
        }
    }

    func refreshStatus(_ reason: String) async {
        healthStatus = await ProbeHealth.status(store)
        log.add("status (\(reason)): \(healthStatus)")
    }

    func listProbeWorkouts() {
        Task {
            for line in await ProbeHealth.listProbeWorkouts(store) { log.add(line) }
        }
    }

    // MARK: Start

    func start() {
        runOfStart = run
        completion = nil
        mirroredAfter = nil
        phase = nil
        phases = []
        pauses = []
        pauseStart = nil
        isPaused = false
        watchHeartRate = nil
        watchUpdates = 0
        syncIdentifier = run.syncs ? UUID().uuidString : nil
        log.add("=== run: \(run.rawValue) ===")
        beeper.start()
        Task {
            await refreshStatus("Start")
            if run == .replaceA, let syncIdentifier {
                let end = Date.now
                log.add(await Self.saveOwn(store: store, start: end - 60, end: end, syncIdentifier: syncIdentifier))
            }
            callStartWatchApp()
        }
    }

    private func callStartWatchApp() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = run.activityType
        let calledAt = Date.now
        workoutStart = calledAt
        log.add("startWatchApp called for \(run.activityType.label)")
        store.startWatchApp(with: configuration) { [weak self] success, error in
            let at = Date.now
            let text =
                "\(secs(at.timeIntervalSince(calledAt))) \(success ? "success" : "failure")"
                + (error.map { " \($0)" } ?? "")
            Task { @MainActor in
                guard let self, self.workoutStart == calledAt else { return }
                self.completion = text
                self.log.add("startWatchApp completion after \(text)")
            }
        }
        startPhases(from: calledAt)
        Task {
            for mark in [10.0, 30.0] {
                try? await Task.sleep(for: .seconds(mark - Date.now.timeIntervalSince(calledAt)))
                guard workoutStart == calledAt, mirroredAfter == nil else { return }
                log.add("no mirrored session \(Int(mark)) s after startWatchApp")
            }
        }
    }

    private func startPhases(from start: Date) {
        phaseTimer?.cancel()
        phaseTimer = Task {
            while !Task.isCancelled {
                let current = StandIn.phase(at: Date.now.timeIntervalSince(start), workoutStart: start)
                if current.index != phase?.index {
                    phase = current
                    phases.append(current)
                    beeper.play()
                    send(.phase(current))
                }
                try? await Task.sleep(for: .seconds(max(0.05, StandIn.end(of: current).timeIntervalSinceNow + 0.01)))
            }
        }
    }

    // MARK: Mirrored session

    private func mirrored(_ session: HKWorkoutSession, at date: Date) {
        session.delegate = self
        self.session = session
        state = session.state
        var line = "mirrored session arrived, state \(session.state.label)"
        if let workoutStart, mirroredAfter == nil {
            mirroredAfter = date.timeIntervalSince(workoutStart)
            line += ", \(secs(date.timeIntervalSince(workoutStart))) after startWatchApp"
        }
        log.add(line, at: date)
        guard let workoutStart else { return }
        send(
            .plan(
                Plan(
                    run: runOfStart.rawValue, workoutStart: workoutStart, activities: runOfStart.activities,
                    syncIdentifier: syncIdentifier,
                    syncVersion: syncIdentifier == nil ? nil : ProbeHealth.watchSyncVersion)))
        if let phase { send(.phase(phase)) }
    }

    func pause() {
        guard !isPaused else { return }
        let at = Date.now
        isPaused = true
        pauseStart = at
        send(.pause(at: at))
        log.add("Pause")
    }

    func resume() {
        guard isPaused, let pauseStart else { return }
        let at = Date.now
        isPaused = false
        pauses.append(Record.Span(start: pauseStart, end: at))
        self.pauseStart = nil
        send(.resume(at: at))
        log.add("Resume")
    }

    /// Ends the Workout: the Watch gets the record and saves.
    func stop() {
        let end = Date.now
        phaseTimer?.cancel()
        phaseTimer = nil
        if let pauseStart {
            pauses.append(Record.Span(start: pauseStart, end: end))
            self.pauseStart = nil
            isPaused = false
        }
        var activities: [Record.Activity] = []
        for (index, phase) in phases.enumerated() where phase.start < end {
            let next = index + 1 < phases.count ? phases[index + 1].start : end
            activities.append(
                Record.Activity(kind: phase.kind, round: phase.round, start: phase.start, end: min(next, end)))
        }
        send(.stop(Record(end: end, activities: activities, pauses: pauses)))
        log.add("Stop: sent \(activities.count) activities and \(pauses.count) Pauses")
    }

    /// The fallback when the Watch never got Stop.
    func forceStop() {
        guard let session else { return log.add("stopActivity: no session") }
        log.add("stopActivity(with: now) on the mirrored session")
        session.stopActivity(with: .now)
    }

    func stopAudio() {
        beeper.stop()
    }

    private func send(_ wire: Wire) {
        guard let session else { return }
        session.sendToRemoteWorkoutSession(data: wire.encoded()) { [weak self] success, error in
            guard !success else { return }
            let text = error.map { "\($0)" } ?? "no error"
            Task { @MainActor in self?.log.add("send failed: \(text)") }
        }
    }

    private func received(_ wire: Wire, at date: Date) {
        switch wire {
        case .status(let heartRate, let updates):
            watchHeartRate = heartRate
            watchUpdates = updates
        case .saved(let start, let end):
            log.add("the Watch saved its workout", at: date)
            if runOfStart == .replaceB, let syncIdentifier {
                Task {
                    log.add(await Self.saveOwn(store: store, start: start, end: end, syncIdentifier: syncIdentifier))
                }
            }
        case .log(let line, let at):
            log.add(line, at: at, from: "watch")
        case .plan, .phase, .pause, .resume, .stop:
            break
        }
    }

    /// Saves a workout the way Temper's iPhone save does, with sync version 1.
    private nonisolated static func saveOwn(
        store: HKHealthStore, start: Date, end: Date, syncIdentifier: String
    ) async -> String {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .highIntensityIntervalTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.addMetadata([
                HKMetadataKeySyncIdentifier: syncIdentifier,
                HKMetadataKeySyncVersion: 1,
                ProbeHealth.markerKey: "watch-health-probe",
                ProbeHealth.runKey: "iPhone v1",
            ])
            try await builder.endCollection(at: end)
            guard let workout = try await builder.finishWorkout() else {
                return "iPhone save, sync \(syncIdentifier.prefix(8)) v1: no workout and no error"
            }
            return "iPhone save, sync \(syncIdentifier.prefix(8)) v1: saved \(workout.uuid.uuidString.prefix(8)), "
                + "\(Int(workout.duration)) s"
        } catch {
            return "iPhone save, sync \(syncIdentifier.prefix(8)) v1: failed: \(error)"
        }
    }

    private func stateChanged(
        _ id: ObjectIdentifier, to new: HKWorkoutSessionState, from old: HKWorkoutSessionState, at date: Date
    ) {
        let current = session.map(ObjectIdentifier.init) == id
        log.add("state \(old.label) → \(new.label)\(current ? "" : " (stale instance)")", at: date)
        guard current else { return }
        state = new
        guard new == .ended else { return }
        session = nil
        phaseTimer?.cancel()
        phaseTimer = nil
        beeper.stop()
        // Give run B's own save and Health a moment, then show what's there.
        Task {
            try? await Task.sleep(for: .seconds(4))
            listProbeWorkouts()
        }
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
        Task { @MainActor in self.log.add("DISCONNECTED from the Watch: \(text)", at: at) }
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
