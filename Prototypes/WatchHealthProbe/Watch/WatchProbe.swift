// PROBE, throwaway. The Watch side. `handle(_:)` logs the workout permission and makes the session whatever it
// says, so a run with no permission shows what HealthKit does. It prepares, mirrors at `.prepared`, waits up to
// 3 s for the iPhone's plan, then starts at the plan's Workout Start. Activities come live from Phase messages or
// from the iPhone's record at Stop, as the plan says. It saves with the plan's sync identifier and version.

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
    private(set) var plan: Plan?
    private(set) var phase: Phase?
    private(set) var heartRate: Double?
    private(set) var heartRateUpdates = 0
    private(set) var heartRateValues = 0
    private(set) var healthStatus = "–"
    /// Asks for Health inside `handle(_:)`, the background launch. For run P2 only.
    var asksInHandle = UserDefaults.standard.bool(forKey: "asksInHandle") {
        didSet { UserDefaults.standard.set(asksInHandle, forKey: "asksInHandle") }
    }

    private var started = false
    private var record: Record?
    /// The date each live activity was asked to begin at, by Phase index, to compare with what HealthKit records.
    private var requested: [String: Date] = [:]
    private var statusTask: Task<Void, Never>?
    /// Log lines waiting for a mirrored session to carry them to the iPhone.
    private var unsent: [Wire] = []

    override init() {
        super.init()
        note("launched")
        logDefaultCollection()
        Task { await refreshStatus("launch") }
    }

    // MARK: Health

    func askForHealth() {
        note("asking for Health from the app's screen")
        Task {
            do {
                try await store.requestAuthorization(toShare: ProbeHealth.share, read: ProbeHealth.read)
                note("Health request returned")
            } catch {
                note("Health request failed: \(error)")
            }
            await refreshStatus("after asking")
        }
    }

    func refreshStatus(_ reason: String) async {
        healthStatus = await ProbeHealth.status(store)
        note("status (\(reason)): \(healthStatus)")
    }

    func listProbeWorkouts() {
        Task {
            for line in await ProbeHealth.listProbeWorkouts(store) { note(line) }
        }
    }

    /// What the live data source collects by default for each activity type Temper uses.
    func logDefaultCollection() {
        let types: [HKWorkoutActivityType] = [.highIntensityIntervalTraining, .traditionalStrengthTraining, .other]
        for type in types {
            for location in [HKWorkoutSessionLocationType.unknown, .indoor] {
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = type
                configuration.locationType = location
                let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                let names = source.typesToCollect.map(\.short).sorted().joined(separator: ", ")
                note("typesToCollect \(type.label), \(location == .indoor ? "indoor" : "no location"): \(names)")
            }
        }
    }

    // MARK: Session

    /// Called from `WKApplicationDelegate.handle(_:)`, after the iPhone's `startWatchApp`.
    func handle(_ configuration: HKWorkoutConfiguration, at date: Date) {
        note("handle(_:) for \(configuration.activityType.label)", at: date)
        let share = store.authorizationStatus(for: HKObjectType.workoutType())
        note("workouts \(share.label) in handle(_:)")
        if asksInHandle {
            askInHandle()
        }
        if let session, session.state != .ended {
            note("handle(_:) while a session is \(session.state.label); ending it first")
            session.end()
        }
        reset()
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            builder.dataSource = source
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            note("session made; collecting \(source.typesToCollect.map(\.short).sorted().joined(separator: ", "))")
            session.prepare()
        } catch {
            note("session not made: \(error)")
        }
    }

    private func askInHandle() {
        let askedAt = Date.now
        note("asking for Health inside handle(_:)")
        Task {
            do {
                try await store.requestAuthorization(toShare: ProbeHealth.share, read: ProbeHealth.read)
                note("request inside handle(_:) returned after \(secs(Date.now.timeIntervalSince(askedAt)))")
            } catch {
                note("request inside handle(_:) failed after \(secs(Date.now.timeIntervalSince(askedAt))): \(error)")
            }
            await refreshStatus("after the request inside handle(_:)")
        }
    }

    private func reset() {
        started = false
        plan = nil
        phase = nil
        record = nil
        requested = [:]
        heartRate = nil
        heartRateUpdates = 0
        heartRateValues = 0
    }

    /// Called from `handleActiveWorkoutRecovery()` after a crash.
    func recover() {
        note("recovering an active session")
        store.recoverActiveWorkoutSession { [weak self] session, error in
            let handed = session.map { Handed(value: $0) }
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                guard let session = handed?.value else { return self.note("recovery failed: \(text ?? "none")") }
                session.delegate = self
                let builder = session.associatedWorkoutBuilder()
                builder.delegate = self
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.store, workoutConfiguration: session.workoutConfiguration)
                self.session = session
                self.builder = builder
                self.state = session.state
                self.started = true
                self.note("recovered, state \(session.state.label)")
            }
        }
    }

    private func prepared() {
        guard let session else { return }
        session.startMirroringToCompanionDevice { [weak self] success, error in
            let text = error.map { "\($0)" }
            Task { @MainActor in
                guard let self else { return }
                guard success else {
                    self.note("mirroring failed: \(text ?? "no error"); starting now with no plan")
                    return self.begin()
                }
                self.note("mirroring started")
                self.mirroringStarted()
                try? await Task.sleep(for: .seconds(3))
                if !self.started {
                    self.note("no plan 3 s after mirroring; starting now")
                    self.begin()
                }
            }
        }
    }

    /// Starts the session and collection at the plan's Workout Start, or now with no plan.
    private func begin() {
        guard !started, let session, let builder, session.state == .prepared else { return }
        started = true
        let start = plan?.workoutStart ?? .now
        if plan?.activities == .record {
            builder.shouldCollectWorkoutEvents = false
        }
        session.startActivity(with: start)
        note("startActivity(with:) dated \(secs(Date.now.timeIntervalSince(start))) ago")
        var metadata: [String: Any] = [
            ProbeHealth.markerKey: "watch-health-probe",
            ProbeHealth.runKey: "\(plan?.run ?? "no plan") (Watch)",
        ]
        if let syncIdentifier = plan?.syncIdentifier, let version = plan?.syncVersion {
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier as NSString
            metadata[HKMetadataKeySyncVersion] = NSNumber(value: version)
        }
        builder.addMetadata(metadata) { [weak self] success, error in
            let text = error.map { "\($0)" } ?? ""
            Task { @MainActor in self?.note("metadata added: \(success) \(text)") }
        }
        builder.beginCollection(withStart: start) { [weak self] success, error in
            let text = error.map { "\($0)" } ?? ""
            Task { @MainActor in
                guard let self else { return }
                self.note("collection began: \(success) \(text)")
                if self.plan?.activities == .live, let phase = self.phase { self.beginActivity(phase) }
            }
        }
    }

    private func beginActivity(_ phase: Phase) {
        guard let session else { return }
        // The first Phase starts with the Workout. Later ones are dated as if they reached the Watch 1.5 s late.
        let date = phase.index == 0 ? phase.start : phase.start - 1.5
        requested["\(phase.index)"] = date
        session.beginNewActivity(
            configuration: session.workoutConfiguration, date: date,
            metadata: [ProbeHealth.phaseKey: phase.kind, ProbeHealth.roundKey: phase.round, "index": phase.index])
        note("beginNewActivity \(phase.kind) \(phase.round), dated \(secs(Date.now.timeIntervalSince(date))) ago")
    }

    private func mirroringStarted() {
        isMirroring = true
        let backlog = unsent
        unsent = []
        for line in backlog { send(line) }
        statusTask?.cancel()
        statusTask = Task {
            while !Task.isCancelled {
                send(.status(heartRate: heartRate, updates: heartRateUpdates))
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    /// Ends from the Watch, with no record from the iPhone.
    func stop() {
        guard let session else { return }
        note("stopActivity(with: now) on the Watch")
        session.stopActivity(with: .now)
    }

    private func stopped(at date: Date) {
        guard let session, let builder else { return }
        let end = record?.end ?? date
        let activities = plan?.activities == .record ? record : nil
        let handed = Handed(value: (session, builder))
        Task {
            let (lines, workout) = await Self.finish(handed, end: end, record: activities)
            for line in lines { note(line) }
            if let workout = workout?.value {
                note("saved workout, as the Watch sees it:")
                for line in await ProbeHealth.describe(workout, store: store) { note(line) }
                send(.saved(start: workout.startDate, end: workout.endDate))
            }
            note("heart-rate updates \(heartRateUpdates), \(heartRateValues) with a value")
            session.end()
        }
    }

    /// Adds the record's activities and Pause events when there is one, then ends collection and saves.
    private nonisolated static func finish(
        _ handed: Handed<(HKWorkoutSession, HKLiveWorkoutBuilder)>, end: Date, record: Record?
    ) async -> ([String], Handed<HKWorkout>?) {
        let (session, builder) = handed.value
        var lines: [String] = []
        if let record {
            for activity in record.activities {
                do {
                    try await builder.addWorkoutActivity(
                        HKWorkoutActivity(
                            workoutConfiguration: session.workoutConfiguration, start: activity.start,
                            end: activity.end,
                            metadata: [ProbeHealth.phaseKey: activity.kind, ProbeHealth.roundKey: activity.round]))
                } catch {
                    lines.append("addWorkoutActivity \(activity.kind) \(activity.round) failed: \(error)")
                }
            }
            lines.append("added \(record.activities.count) activities from the record")
            let events = record.pauses.flatMap { pause in
                [
                    HKWorkoutEvent(
                        type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
                    HKWorkoutEvent(
                        type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
                ]
            }
            if !events.isEmpty {
                do {
                    try await builder.addWorkoutEvents(events)
                    lines.append("added \(events.count) Pause events from the record")
                } catch {
                    lines.append("addWorkoutEvents failed: \(error)")
                }
            }
        }
        do {
            try await builder.endCollection(at: end)
        } catch {
            lines.append("endCollection failed: \(error)")
        }
        do {
            guard let workout = try await builder.finishWorkout() else {
                lines.append("finishWorkout returned no workout and no error")
                return (lines, nil)
            }
            lines.append("finishWorkout saved \(workout.uuid.uuidString.prefix(8)), \(Int(workout.duration)) s")
            return (lines, Handed(value: workout))
        } catch {
            lines.append("finishWorkout failed: \(error)")
            return (lines, nil)
        }
    }

    private func ended() {
        statusTask?.cancel()
        statusTask = nil
        isMirroring = false
        note("ended")
    }

    // MARK: Link

    private func send(_ wire: Wire) {
        guard let session else { return }
        session.sendToRemoteWorkoutSession(data: wire.encoded()) { [weak self] success, error in
            guard !success else { return }
            let text = error.map { "\($0)" } ?? "no error"
            // Not forwarded: it would fail the same way.
            Task { @MainActor in self?.log.add("send failed: \(text)") }
        }
    }

    private func received(_ wire: Wire) {
        switch wire {
        case .plan(let plan):
            self.plan = plan
            note(
                "plan: \(plan.run), activities \(plan.activities.rawValue), "
                    + "sync \(plan.syncIdentifier.map { String($0.prefix(8)) } ?? "none") v\(plan.syncVersion ?? 0)")
            begin()
        case .phase(let phase):
            self.phase = phase
            if started, plan?.activities == .live { beginActivity(phase) }
        case .pause(let at):
            note("Pause from the iPhone, \(secs(Date.now.timeIntervalSince(at))) after its tap")
            session?.pause()
        case .resume(let at):
            note("Resume from the iPhone, \(secs(Date.now.timeIntervalSince(at))) after its tap")
            session?.resume()
        case .stop(let record):
            self.record = record
            note("Stop from the iPhone with \(record.activities.count) activities and \(record.pauses.count) Pauses")
            if plan?.activities == .live { session?.endCurrentActivity(on: record.end) }
            session?.stopActivity(with: record.end)
        case .status, .saved, .log:
            break
        }
    }

    // MARK: Log

    /// Logs here and forwards the line to the iPhone, holding it until a mirrored session exists.
    func note(_ text: String, at date: Date = .now) {
        log.add(text, at: date)
        let wire = Wire.log(line: text, at: date)
        if isMirroring {
            send(wire)
        } else if unsent.count < 300 {
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
        case .stopped: stopped(at: date)
        case .ended: ended()
        default: break
        }
    }

    private func activityChanged(_ began: Bool, _ handed: Handed<HKWorkoutActivity>, at date: Date) {
        let activity = handed.value
        let index = activity.metadata?["index"].map { "\($0)" } ?? "?"
        let name =
            "\(activity.metadata?[ProbeHealth.phaseKey] ?? "?") \(activity.metadata?[ProbeHealth.roundKey] ?? "-")"
        if began {
            let asked = requested[index].map { secs(activity.startDate.timeIntervalSince($0)) } ?? "?"
            note("activity began: \(name), recorded start minus asked \(asked)", at: date)
        } else {
            note(
                "activity ended: \(name), \(activity.endDate.map { secs($0.timeIntervalSince(activity.startDate)) } ?? "open")",
                at: date)
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
        let messages = data.compactMap(Wire.decode)
        Task { @MainActor in
            for message in messages { self.received(message) }
        }
    }
}

extension WatchProbe: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate) else { return }
        let bpm = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()?
            .doubleValue(for: .count().unitDivided(by: .minute()))
        Task { @MainActor in
            self.heartRateUpdates += 1
            if let bpm {
                self.heartRateValues += 1
                self.heartRate = bpm
            }
            if self.heartRateUpdates == 1 {
                self.note("first heart-rate update: \(bpm.map { "\(Int($0)) bpm" } ?? "no value in statistics")")
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        let event = workoutBuilder.workoutEvents.last.map { $0.type.label } ?? "none"
        Task { @MainActor in self.note("builder collected event: \(event)") }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didBegin workoutActivity: HKWorkoutActivity)
    {
        let at = Date.now
        let handed = Handed(value: workoutActivity)
        Task { @MainActor in self.activityChanged(true, handed, at: at) }
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didEnd workoutActivity: HKWorkoutActivity) {
        let at = Date.now
        let handed = Handed(value: workoutActivity)
        Task { @MainActor in self.activityChanged(false, handed, at: at) }
    }
}
