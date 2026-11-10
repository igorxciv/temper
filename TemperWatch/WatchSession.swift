import Foundation
import HealthKit
import Observation
import TemperCore

/// The Watch's workout session, which carries the running link to the iPhone.
///
/// `WatchFlow` decides what to show and do. This adapter only calls HealthKit: it starts the session the iPhone asked
/// for, mirrors it once it's prepared, hands each message to the flow, and carries out the flow's effects.
@Observable
final class WatchSession: NSObject {
    static let shared = WatchSession()

    /// What the Watch shows, as the flow last left it.
    private(set) var screen = WatchFlow.Screen.idle

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
        case .beginCollection(let start):
            collectionStart = start
            beginCollectionIfRunning()
        case .endWithoutSaving:
            collectionStart = nil
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
        session.delegate = self
        self.session = session
        self.builder = builder
        haptics.session = session
        collectionStart = nil
        hasBegunCollection = false
        session.prepare()
    }

    /// The session mirrors before its activity starts, so the iPhone's `begin` can arrive while it's only prepared.
    /// Collection begins once it runs, dated at the Workout's Start either way.
    private func beginCollectionIfRunning() {
        guard let start = collectionStart, let session, let builder, session.state == .running else { return }
        collectionStart = nil
        hasBegunCollection = true
        Task { try? await builder.beginCollection(at: start) }
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
