import Foundation
import HealthKit
import Observation
import TemperCore
import WatchKit

/// The Watch's workout session, which carries the running link to the iPhone.
///
/// `WatchFlow` decides what to show and do. This adapter only calls HealthKit: it starts the session the iPhone asked
/// for, mirrors it once it's prepared, hands each message and tap to the flow, and carries out the flow's effects.
/// Alongside the flow, it reads what the Zones need when the session starts and passes on each heart-rate reading.
///
/// The session collects heart rate and energy, and pauses and resumes live, but collects no events of its own. At the
/// end the Phases and Pauses come from the iPhone's Health record, so the Watch's copy carries the iPhone's times.
///
/// The Watch owns the session, though the iPhone runs the Workout, because only a workout session keeps the Watch app
/// awake and reachable with the wrist down. So a dropout doesn't stop the recording: HealthKit reconnects the session
/// by itself, and the iPhone catches the Watch up through the new mirrored instance. After a Watch app crash,
/// HealthKit hands the session back and the same thing happens.
@Observable
final class WatchSession: NSObject {
    static let shared = WatchSession()

    /// What the Watch shows, as the flow last left it.
    private(set) var screen = WatchFlow.Screen.idle
    /// The Workout's heart rate, observed apart from `screen` so each reading redraws only the slot.
    let heartRate = LiveHeartRate()

    @ObservationIgnored private var flow = WatchFlow()
    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private let haptics = WristHaptics()
    /// The configuration the iPhone opened the Watch with, for the session the flow starts.
    @ObservationIgnored private var configuration: HKWorkoutConfiguration?
    /// The Workout's Start, held from the iPhone's `begin` until the session runs and collection can begin.
    @ObservationIgnored private var collectionStart: Date?
    /// True once collection has been asked to begin, so only a builder with something to discard is discarded.
    @ObservationIgnored private var hasBegunCollection = false
    /// The record to save, from the flow's `endAndSave` until the session has stopped and the save can begin.
    @ObservationIgnored private var pendingSave: HealthRecord?
    /// What the Zones are worked out from, read when the session starts and held until the Workout's Start is known.
    @ObservationIgnored private var zoneInputs: WatchHealth.ZoneInputs?
    /// The Workout's Start, from the iPhone's `begin`, which dates the age the Zones use.
    @ObservationIgnored private var workoutStart: Date?
    /// The wait for the iPhone's first message. The flow ignores one that runs out after the message came.
    @ObservationIgnored private var firstMessageWait: Task<Void, Never>?
    /// When the session last got anything from the iPhone, read as it arrived.
    @ObservationIgnored private var lastHeard: Date?
    /// Counts the time out of contact during a dropout, for the flow.
    @ObservationIgnored private var outOfContactTimer: Task<Void, Never>?

    /// Called from the app delegate's `handle(_:)`, after the iPhone's `startWatchApp` at Start.
    func handle(_ configuration: HKWorkoutConfiguration) {
        self.configuration = configuration
        apply(.launched(workoutsAllowed: WatchHealth.workoutsAllowed))
    }

    /// Called from the app delegate's `handleActiveWorkoutRecovery()`, when the Watch app opens again after a crash
    /// during a Workout. The Watch persisted nothing, so it takes the session back and waits for the iPhone.
    func recover() {
        Task {
            guard let session = try? await store.recoverActiveWorkoutSession() else { return }
            guard self.session == nil else {
                // The iPhone opened the Watch for a new Workout meanwhile, so the old session has nothing to follow.
                session.end()
                return
            }
            follow(session)
            apply(.recovered(isPaused: session.state == .paused))
            // A session that was running is left to HealthKit, which reconnects it to the iPhone by itself.
            if session.state == .prepared {
                // The crash came before its activity started, and no change of state will say so again.
                prepared(session)
            }
        }
    }

    /// Done on the complete screen.
    func done() {
        apply(.doneTapped)
    }

    /// A tap on the running screen's capsule or the secondary page, dated now on the Watch's clock.
    func tap(_ command: WatchCommand) {
        apply(.tapped(command, at: .now))
    }

    private func apply(_ event: WatchFlow.Event) {
        let effects = flow.handle(event)
        screen = flow.screen
        for effect in effects {
            perform(effect)
        }
    }

    private func perform(_ effect: WatchFlow.Effect) {
        switch effect {
        case .startSession:
            startSession()
        case .awaitFirstMessage(let duration):
            firstMessageWait?.cancel()
            // The session keeps the app running with the wrist down, so the wait runs out on time.
            firstMessageWait = Task {
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                apply(.firstMessageTimedOut)
            }
        case .beginCollection(let start):
            collectionStart = start
            workoutStart = start
            settleZones()
            beginCollectionIfRunning()
        case .pauseSession:
            session?.pause()
        case .resumeSession:
            session?.resume()
        case .endAndSave(let record):
            collectionStart = nil
            guard hasBegunCollection, let session else {
                session?.end()
                return
            }
            pendingSave = record
            // Stopped at the record's end, then saved once it has stopped, as the Health probe for #108 did. A
            // session another workout app took over has ended already, and its builder can still save.
            if session.state == .stopped || session.state == .ended {
                save(session)
            } else {
                session.stopActivity(with: record.end)
            }
        case .endWithoutSaving:
            collectionStart = nil
            pendingSave = nil
            if hasBegunCollection {
                builder?.discardWorkout()
            }
            session?.end()
        case .send(let message):
            send(message)
        case .signalRefused:
            WKInterfaceDevice.current().play(.failure)
        case .startOutOfContactTimer:
            outOfContactTimer?.cancel()
            outOfContactTimer = Task {
                // The continuous clock keeps counting while the Watch sleeps.
                try? await Task.sleep(for: WatchFlow.outOfContactLimit, clock: .continuous)
                // A dropout that ended as the time ran out has cancelled this.
                guard !Task.isCancelled else { return }
                apply(.outOfContactTimerFired)
            }
        case .stopOutOfContactTimer:
            outOfContactTimer?.cancel()
            outOfContactTimer = nil
        case .cancelHaptics(let date):
            haptics.cancel(after: date)
        case .cancelAllHaptics:
            haptics.cancelAll()
        case .playHaptic(let cue):
            haptics.play(cue)
        case .scheduleHaptics(let cues):
            haptics.schedule(cues)
        }
    }

    /// A send that fails, as it can in the moments before a dropout is noticed, loses the tap. During a dropout the
    /// flow sends none.
    private func send(_ message: MessageFromWatch) {
        guard let session, let data = try? message.json() else { return }
        Task { try? await session.sendToRemoteWorkoutSession(data: data) }
    }

    private func startSession() {
        guard let configuration,
            let session = try? HKWorkoutSession(healthStore: store, configuration: configuration)
        else {
            apply(.sessionEnded(at: .now))
            return
        }
        follow(session)
        session.prepare()
    }

    /// Takes on a session, new or recovered after a crash, and reads what its Zones need.
    private func follow(_ session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: session.workoutConfiguration)
        // The Pauses come from the iPhone's record at the end, with its times, rather than from the session's live
        // pauses, which reach the Watch moments late.
        builder.shouldCollectWorkoutEvents = false
        builder.delegate = self
        session.delegate = self
        self.session = session
        self.builder = builder
        haptics.session = session
        collectionStart = nil
        // A recovered session's builder may have begun before the crash.
        hasBegunCollection = builder.startDate != nil
        pendingSave = nil
        lastHeard = nil
        heartRate.current = WorkoutHeartRate(zones: nil)
        zoneInputs = nil
        workoutStart = nil
        Task {
            let inputs = await WatchHealth.zoneInputs()
            guard session === self.session else { return }
            zoneInputs = inputs
            settleZones()
        }
    }

    /// Sets the Zones once both the Health reads and the Workout's Start are in, and keeps them until Stop. Without a
    /// date of birth or a resting rate they stay `nil`, and the meter stays hidden.
    private func settleZones() {
        guard let zoneInputs, let workoutStart else { return }
        self.zoneInputs = nil
        heartRate.current.zones = zoneInputs.zones(start: workoutStart)
    }

    /// The session mirrors before its activity starts, so the iPhone's `begin` can arrive while it's only prepared.
    /// Collection begins once it runs, dated at the Workout's Start either way. A session recovered after a crash
    /// has usually begun already, and the iPhone's `begin` to it changes nothing.
    private func beginCollectionIfRunning() {
        guard let start = collectionStart, let session, let builder, session.state == .running else { return }
        collectionStart = nil
        guard !hasBegunCollection else { return }
        hasBegunCollection = true
        Task { try? await builder.beginCollection(at: start) }
    }

    /// Saves the pending record and ends the session. If any step fails, what was collected is discarded and the
    /// iPhone's own copy, which has every Phase, covers the Workout.
    ///
    /// The live builder adds one activity of its own spanning the whole workout. It's left alone: on the devices it did
    /// no harm next to the Phases added from the record (#124, run B).
    private func save(_ session: HKWorkoutSession) {
        guard let record = pendingSave.take(), let builder else {
            session.end()
            return
        }
        let configuration = session.workoutConfiguration
        Task {
            do {
                try await builder.add(record, configuration: configuration)
                try await builder.endCollection(at: record.end)
                _ = try await builder.finishWorkout()
            } catch {
                builder.discardWorkout()
            }
            session.end()
        }
    }

    /// Mirrors only once the session is prepared, which works around an iOS 26 bug that dropped the mirroring of
    /// iPhone-started sessions. The activity starts whether or not mirroring did.
    private func prepared(_ session: HKWorkoutSession) {
        Task {
            try? await session.startMirroringToCompanionDevice()
            session.startActivity(with: .now)
        }
    }

    private func stateChanged(_ session: HKWorkoutSession, to state: HKWorkoutSessionState, at date: Date) {
        guard session === self.session else { return }
        switch state {
        case .prepared:
            prepared(session)
        case .running:
            beginCollectionIfRunning()
        case .stopped:
            if pendingSave != nil {
                save(session)
            }
            apply(.sessionStopped)
        case .ended:
            // The flow hears of it while the builder is still here. A session the Watch didn't end was ended by the
            // system, as when another workout app starts its own, and the flow may save what it collected. HealthKit
            // reports that error before this change of state, so the change alone is acted on.
            apply(.sessionEnded(at: date))
            if pendingSave != nil {
                save(session)
            }
            self.session = nil
            builder = nil
        case .notStarted, .paused:
            break
        @unknown default:
            break
        }
    }

    /// Each callback hops to the main actor by itself, so a disconnect can be handled after the messages of the
    /// reconnect that followed it. That one is stale, and would start a dropout nothing ends.
    private func disconnected(_ session: HKWorkoutSession, at date: Date) {
        guard session === self.session, lastHeard.map({ date >= $0 }) ?? true else { return }
        apply(.disconnected(at: date))
    }

    private func collected(_ reading: HeartRateReading, from builder: HKLiveWorkoutBuilder) {
        guard builder === self.builder else { return }
        heartRate.current.record(latest: reading.latest, average: reading.average, maximum: reading.maximum)
    }

    /// Each message is timed as it's handled, in the same main-actor turn as the haptics it cancels, so no haptic can
    /// start between the two and be counted as cancelled.
    private func received(_ messages: [MessageToWatch], from session: HKWorkoutSession, at arrival: Date) {
        guard session === self.session else { return }
        lastHeard = max(lastHeard ?? arrival, arrival)
        for message in messages {
            apply(.received(message, at: .now))
        }
    }
}

extension WatchSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        Task { @MainActor in self.stateChanged(workoutSession, to: toState, at: date) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}

    /// Only this starts a dropout. HealthKit then tries to reconnect by itself, and the iPhone's messages through
    /// the new mirrored instance end the dropout.
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        let date = Date.now
        Task { @MainActor in self.disconnected(workoutSession, at: date) }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Data this build can't read is dropped. A `begin` of another version still decodes, and shows Update Temper.
        let messages = data.compactMap { try? MessageToWatch(json: $0) }
        let arrival = Date.now
        Task { @MainActor in self.received(messages, from: workoutSession, at: arrival) }
    }
}

/// The builder's heart-rate statistics so far, in bpm.
private nonisolated struct HeartRateReading: Sendable {
    let latest: Double
    let average: Double
    let maximum: Double

    init?(_ statistics: HKStatistics?) {
        guard let statistics, let latest = statistics.mostRecentQuantity(),
            let average = statistics.averageQuantity(), let maximum = statistics.maximumQuantity()
        else { return nil }
        self.latest = latest.doubleValue(for: .beatsPerMinute)
        self.average = average.doubleValue(for: .beatsPerMinute)
        self.maximum = maximum.doubleValue(for: .beatsPerMinute)
    }
}

extension WatchSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let type = HKQuantityType(.heartRate)
        guard collectedTypes.contains(type), let reading = HeartRateReading(workoutBuilder.statistics(for: type))
        else { return }
        Task { @MainActor in self.collected(reading, from: workoutBuilder) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
