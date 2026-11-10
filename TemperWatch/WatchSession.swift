import Foundation
import HealthKit
import Observation
import TemperCore

/// The Watch's workout session, which carries the running link to the iPhone.
///
/// `WatchFlow` decides what to show and do. This adapter only calls HealthKit: it starts the session the iPhone asked
/// for, mirrors it once it's prepared, hands each message to the flow, and carries out the flow's effects. Alongside
/// the flow, it reads what the Zones need when the session starts and passes on each heart-rate reading.
///
/// The session collects heart rate and energy, and pauses and resumes live, but collects no events of its own. At the
/// end the Phases and Pauses come from the iPhone's Health record, so the Watch's copy carries the iPhone's times.
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

    /// Called from the app delegate's `handle(_:)`, after the iPhone's `startWatchApp` at Start.
    func handle(_ configuration: HKWorkoutConfiguration) {
        self.configuration = configuration
        apply(.launched(workoutsAllowed: WatchHealth.workoutsAllowed))
    }

    /// Done on the complete screen.
    func done() {
        apply(.doneTapped)
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
            // Stopped at the record's end, then saved once it has stopped, as the Health probe for #108 did.
            if session.state == .stopped {
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

    private func startSession() {
        guard let configuration,
            let session = try? HKWorkoutSession(healthStore: store, configuration: configuration)
        else {
            apply(.sessionEnded)
            return
        }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
        // The Pauses come from the iPhone's record at the end, with its times, rather than from the session's live
        // pauses, which reach the Watch moments late.
        builder.shouldCollectWorkoutEvents = false
        builder.delegate = self
        session.delegate = self
        self.session = session
        self.builder = builder
        haptics.session = session
        collectionStart = nil
        hasBegunCollection = false
        pendingSave = nil
        heartRate.current = WorkoutHeartRate(zones: nil)
        zoneInputs = nil
        workoutStart = nil
        session.prepare()
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
    /// Collection begins once it runs, dated at the Workout's Start either way.
    private func beginCollectionIfRunning() {
        guard let start = collectionStart, let session, let builder, session.state == .running else { return }
        collectionStart = nil
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

    private func stateChanged(_ session: HKWorkoutSession, to state: HKWorkoutSessionState) {
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
            self.session = nil
            builder = nil
            apply(.sessionEnded)
        case .notStarted, .paused:
            break
        @unknown default:
            break
        }
    }

    private func collected(_ reading: HeartRateReading, from builder: HKLiveWorkoutBuilder) {
        guard builder === self.builder else { return }
        heartRate.current.record(latest: reading.latest, average: reading.average, maximum: reading.maximum)
    }

    /// Each message is timed as it's handled, in the same main-actor turn as the haptics it cancels, so no haptic can
    /// start between the two and be counted as cancelled.
    private func received(_ messages: [MessageToWatch], from session: HKWorkoutSession) {
        guard session === self.session else { return }
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
        Task { @MainActor in self.stateChanged(workoutSession, to: toState) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Data this build can't read is dropped. A `begin` of another version still decodes, and shows Update Temper.
        let messages = data.compactMap { try? MessageToWatch(json: $0) }
        Task { @MainActor in self.received(messages, from: workoutSession) }
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
