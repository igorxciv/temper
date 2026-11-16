import Foundation
import Observation
import TemperCore
import UIKit

/// Saves each ended Workout to Health, at most once, and asks for permission when Settings says to. The one request
/// covers everything the Watch will need as well, so the Watch never asks. The owner can turn saving off in Settings
/// without taking back Health access, which keeps the Watch following each Workout.
///
/// A save counts as done only when Health returns the workout. A locked iPhone can return nothing and save nothing,
/// so until then the save stays pending in `UserDefaults`, and it's tried again with its sync version raised by 1
/// when Temper launches, comes to the front, or learns protected data became available. Whichever attempt lands last
/// replaces the others in Health. A pending save is dropped after ``attemptLimit`` attempts made with protected data
/// available, or once writing isn't allowed. Nothing on screen reports a save.
@Observable
final class HealthSaves {
    /// Attempts made while locked don't count, because a locked save's outcome says nothing about whether saving
    /// works. The limit keeps a save Health never confirms from being tried forever.
    static let attemptLimit = 3

    /// Where ``isOn`` is kept.
    static let isOnKey = "savesToHealth"

    /// Settings' Apple Health row, from the statuses as last read and the switch, or `nil` before the first read.
    var row: AppleHealthRow? {
        statuses.map { AppleHealthRow(writeStatus: $0.write, requestStatus: $0.request, isOn: isOn) }
    }

    /// The owner's switch in Settings, on until they turn it off. Turning it off stops saving Workouts that end after,
    /// and leaves saves already pending to finish. It's read at Start for the Watch too, and can't change during a
    /// Workout, since Settings isn't on screen then.
    var isOn: Bool {
        didSet { defaults.set(isOn, forKey: Self.isOnKey) }
    }

    /// The statuses as last read, or `nil` before the first read.
    private var statuses: (write: HealthWriteStatus, request: HealthRequestStatus)?

    @ObservationIgnored private let store: any HealthWorkoutStore
    @ObservationIgnored private let defaults: UserDefaults
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
        self.defaults = defaults
        isOn = defaults.object(forKey: Self.isOnKey) as? Bool ?? true
        pending = PendingHealthSaves(defaults: defaults)
        self.isProtectedDataAvailable = isProtectedDataAvailable
    }

    func refreshStatus() async {
        let requestStatus = await store.requestStatus
        statuses = (store.writeStatus, requestStatus)
    }

    func requestPermission() async {
        await store.requestPermission()
        await refreshStatus()
    }

    /// Saves the Health workout of an ended Workout, if writing is allowed and the owner has saving on. `record` is the
    /// first attempt's, or `nil` for a Workout that ran for less than ``HealthRecord/minimumActiveTime`` and so saves
    /// nothing.
    ///
    /// The background task and the pending save are in place before this returns, so the save can finish, or be
    /// tried again later, even if the app is suspended straight after.
    @discardableResult
    func save(_ record: HealthRecord?) -> Task<Void, Never> {
        let backgroundTask = BackgroundTask(named: "Health")
        guard let record, isOn, store.writeStatus == .allowed else {
            backgroundTask.end()
            return Task {}
        }
        pending.put(PendingHealthSave(record: record, countedAttempts: 0))
        return Task {
            await attempt(record.workoutID)
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
                pending.remove(pendingSave.record.workoutID)
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
        case .saved, .notAllowed:
            pending.remove(workoutID)
        case .unverified, .failed:
            if next.countedAttempts >= Self.attemptLimit {
                pending.remove(workoutID)
            }
        }
    }
}
