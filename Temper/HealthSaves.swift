import Foundation
import Observation
import TemperCore
import UIKit

/// Whether Temper may write workouts to Health.
enum HealthWriteStatus {
    /// The owner hasn't been asked.
    case notDetermined
    case allowed
    /// The owner said no, or the device has no Health.
    case denied
}

/// What one attempt at saving a Health workout came to.
enum HealthSaveOutcome {
    /// Health returned the workout.
    case saved
    /// Health returned neither a workout nor an error. A save while locked can do this and still land, or not.
    case unverified
    case failed
    /// Health refused because Temper isn't allowed to write.
    case notAllowed
}

/// The one line the timing log gets for an attempt at saving a Health workout, or for a pending save dropped once
/// writing isn't allowed.
enum HealthAttemptResult: String {
    case saved
    case unverified
    case failed
    /// The pending save was removed without being confirmed: Health refused it as not allowed, or it used up its
    /// last attempt.
    case dropped
}

/// Where Health workouts are saved: HealthKit in the app, and a fake in tests.
protocol HealthWorkoutStore {
    var writeStatus: HealthWriteStatus { get }
    /// Shows the system sheet asking to write workouts, if the owner hasn't answered it yet.
    func requestPermission() async
    func save(_ record: HealthRecord) async -> HealthSaveOutcome
}

/// Saves each ended Workout to Health, at most once, and asks for permission when Settings says to.
///
/// A save counts as done only when Health returns the workout. A locked iPhone can return nothing and save nothing,
/// so until then the save stays pending in `UserDefaults`, and it's tried again with its sync version raised by 1
/// when Temper launches, comes to the front, or learns protected data became available. Whichever attempt lands last
/// replaces the others in Health. A pending save is dropped after ``attemptLimit`` attempts made with protected data
/// available, or once writing isn't allowed. Nothing on screen reports a save.
@Observable
final class HealthSaves {
    static let attemptLimit = 3

    /// The write status as last read, or `nil` before the first read.
    private(set) var writeStatus: HealthWriteStatus?

    #if DEBUG
        /// Where each attempt's result is logged: the Workout's own log, or a new one for a retry with none.
        @ObservationIgnored var timingLog: TimingLog?
        /// Called with each result written to the timing log, so tests can read them.
        @ObservationIgnored var didLog: (HealthAttemptResult) -> Void = { _ in }
    #endif

    @ObservationIgnored private let store: any HealthWorkoutStore
    @ObservationIgnored private let pending: PendingHealthSaves
    @ObservationIgnored private let isProtectedDataAvailable: () -> Bool
    /// The Workouts with an attempt under way, so overlapping triggers don't save one twice at once.
    @ObservationIgnored private var attempting: Set<UUID> = []

    init(
        store: any HealthWorkoutStore = HealthKitWorkouts(),
        defaults: UserDefaults = .standard,
        isProtectedDataAvailable: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable }
    ) {
        self.store = store
        pending = PendingHealthSaves(defaults: defaults)
        self.isProtectedDataAvailable = isProtectedDataAvailable
    }

    func refreshStatus() {
        writeStatus = store.writeStatus
    }

    func requestPermission() async {
        await store.requestPermission()
        refreshStatus()
    }

    /// Saves the Health workout of an ended Workout, if writing is allowed and it ran long enough.
    ///
    /// The background task and the pending save are in place before this returns, so the save can finish, or be
    /// tried again later, even if the app is suspended straight after. `instant` and `date` are read together, on
    /// the engine's clock and the wall clock.
    @discardableResult
    func save<Instant>(
        _ record: WorkoutRecord<Instant>,
        of workoutType: WorkoutType,
        workoutID: UUID,
        at instant: Instant,
        date: Date
    ) -> Task<Void, Never> where Instant.Duration == Duration {
        let backgroundTask = BackgroundTask(named: "Health")
        guard
            let health = HealthRecord(
                record, of: workoutType, workoutID: workoutID, attempt: 1, at: instant, date: date),
            store.writeStatus == .allowed
        else {
            backgroundTask.end()
            return Task {}
        }
        pending.put(PendingHealthSave(record: health, countedAttempts: 0))
        return Task {
            await attempt(workoutID)
            backgroundTask.end()
        }
    }

    /// Tries every pending save again, if protected data is available.
    func retryPending() async {
        guard isProtectedDataAvailable(), !pending.all.isEmpty else { return }
        let backgroundTask = BackgroundTask(named: "Health")
        defer { backgroundTask.end() }
        guard store.writeStatus == .allowed else {
            for pendingSave in pending.all {
                drop(pendingSave.record)
            }
            return
        }
        for pendingSave in pending.all {
            await attempt(pendingSave.record.workoutID)
        }
    }

    /// Retries pending saves now, at launch, and again whenever Temper comes to the front or protected data becomes
    /// available. The app's own adapter calls this once.
    func retryWhenPossible() {
        Task { await retryPending() }
        for name in [
            UIApplication.willEnterForegroundNotification, UIApplication.protectedDataDidBecomeAvailableNotification,
        ] {
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    await self?.retryPending()
                }
            }
        }
    }

    /// Stores the next attempt before making this one, so a save cut off midway is still tried again with a higher
    /// version.
    private func attempt(_ workoutID: UUID) async {
        guard !attempting.contains(workoutID), let current = pending[workoutID: workoutID] else { return }
        attempting.insert(workoutID)
        defer { attempting.remove(workoutID) }
        let next = PendingHealthSave(
            record: current.record.withSyncVersion(current.record.syncVersion + 1),
            countedAttempts: current.countedAttempts + (isProtectedDataAvailable() ? 1 : 0)
        )
        pending.put(next)
        switch await store.save(current.record) {
        case .saved:
            pending.remove(workoutID)
            log(.saved, current.record)
        case .notAllowed:
            drop(current.record)
        case .unverified where next.countedAttempts >= Self.attemptLimit,
            .failed where next.countedAttempts >= Self.attemptLimit:
            drop(current.record)
        case .unverified:
            log(.unverified, current.record)
        case .failed:
            log(.failed, current.record)
        }
    }

    private func drop(_ record: HealthRecord) {
        pending.remove(record.workoutID)
        log(.dropped, record)
    }

    private func log(_ result: HealthAttemptResult, _ record: HealthRecord) {
        #if DEBUG
            if timingLog == nil {
                timingLog = TimingLog()
            }
            timingLog?.write("health", ["outcome": result.rawValue, "version": record.syncVersion])
            didLog(result)
        #endif
    }
}

/// Keeps the app running for a save after it leaves the front, until `end()`, or until iOS calls time.
private final class BackgroundTask {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(named name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
