import Foundation
import TemperCore
import Testing

@testable import Temper

/// Stands in for HealthKit: it answers with the statuses and outcomes it's given, and keeps every record it was asked
/// to save.
private final class FakeHealthStore: HealthWorkoutStore {
    var writeStatus: HealthWriteStatus = .allowed
    var requestStatus: HealthRequestStatus = .unnecessary
    /// The outcome of each save in turn. Once they run out, every save is confirmed.
    var outcomes: [HealthSaveOutcome] = []
    private(set) var saved: [HealthRecord] = []
    private(set) var permissionRequests = 0

    /// Called when asked for permission, as the system sheet would be shown.
    var duringPermissionRequest: () -> Void = {}
    /// Called with each record while it's being saved, before the outcome returns.
    var duringSave: (HealthRecord) async -> Void = { _ in }

    func requestPermission() async {
        permissionRequests += 1
        duringPermissionRequest()
    }

    func save(_ record: HealthRecord) async -> HealthSaveOutcome {
        saved.append(record)
        await duringSave(record)
        return outcomes.isEmpty ? .saved : outcomes.removeFirst()
    }
}

/// The parts of a test: the fake HealthKit, a `UserDefaults` suite no other test can see, and a way to say whether
/// protected data is available.
@MainActor
private final class Harness {
    let store = FakeHealthStore()
    let defaults: UserDefaults
    var isProtectedDataAvailable = true
    private let suite = "TemperTests.\(UUID().uuidString)"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suite)
    }

    /// A Health adapter as Temper makes one at launch, over the same defaults each time.
    func launch() -> HealthSaves {
        HealthSaves(store: store, defaults: defaults) { [unowned self] in isProtectedDataAvailable }
    }
}

private let start = ContinuousClock.now
private let startDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// The Health record of a Stopwatch's Work that ran for `seconds` from Start, with no Prepare, or `nil` if it ran for
/// less than a minute.
private func stopwatch(seconds: Int, workoutID: UUID = UUID()) -> HealthRecord? {
    let end = start + .seconds(seconds)
    let record = WorkoutRecord(
        start: start, end: end, pauses: [],
        phases: [.init(kind: .work, round: nil, start: start, end: end)]
    )
    return HealthRecord(
        record, filedAs: .other, workoutID: workoutID, attempt: 1, anchor: ClockAnchor(instant: start, date: startDate))
}

@MainActor
struct HealthSavesTests {
    @Test func `An ended Workout of a minute or more is saved once, and leaves nothing pending`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        let workoutID = UUID()

        await health.save(stopwatch(seconds: 60, workoutID: workoutID)).value

        #expect(harness.store.saved.count == 1)
        #expect(harness.store.saved.first?.syncIdentifier == workoutID.uuidString)
        #expect(harness.store.saved.first?.syncVersion == 1)
        #expect(harness.store.saved.first?.start == startDate)
        await harness.launch().retryPending()
        #expect(harness.store.saved.count == 1)
    }

    /// A save Temper is suspended before attempting is still tried again later.
    @Test func `The pending save is stored before save returns`() async throws {
        let harness = try Harness()
        let workoutID = UUID()

        let saving = harness.launch().save(stopwatch(seconds: 90, workoutID: workoutID))

        #expect(harness.store.saved.isEmpty)
        #expect(PendingHealthSaves(defaults: harness.defaults)[workoutID: workoutID]?.record.syncVersion == 1)
        await saving.value
    }

    /// A save cut off midway may still land, so the retry needs a higher version to replace it.
    @Test func `The next version is stored before an attempt is made`() async throws {
        let harness = try Harness()
        let workoutID = UUID()
        var storedDuringSave: Int?
        harness.store.duringSave = { [defaults = harness.defaults] _ in
            storedDuringSave = PendingHealthSaves(defaults: defaults)[workoutID: workoutID]?.record.syncVersion
        }

        await harness.launch().save(stopwatch(seconds: 90, workoutID: workoutID)).value

        #expect(storedDuringSave == 2)
    }

    @Test func `A retry while an attempt is under way doesn't save the same Workout again`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        harness.store.duringSave = { [unowned store = harness.store, unowned health] _ in
            guard store.saved.count == 1 else { return }
            await health.retryPending()
        }

        await health.save(stopwatch(seconds: 90)).value

        #expect(harness.store.saved.map(\.syncVersion) == [1])
    }

    @Test func `A Workout of less than a minute saves nothing`() async throws {
        let harness = try Harness()

        await harness.launch().save(stopwatch(seconds: 59)).value

        #expect(harness.store.saved.isEmpty)
    }

    @Test(arguments: [HealthWriteStatus.notDetermined, .denied])
    func `Unless writing is allowed, an ended Workout saves nothing and leaves nothing to retry`(
        status: HealthWriteStatus
    ) async throws {
        let harness = try Harness()
        harness.store.writeStatus = status

        await harness.launch().save(stopwatch(seconds: 90)).value
        harness.store.writeStatus = .allowed
        await harness.launch().retryPending()

        #expect(harness.store.saved.isEmpty)
    }

    @Test func `Saving is on until the owner turns it off, and stays as they left it after a relaunch`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        #expect(health.isOn)

        health.isOn = false

        #expect(!harness.launch().isOn)
    }

    @Test func `With saving turned off, an ended Workout saves nothing and leaves nothing to retry`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        health.isOn = false

        await health.save(stopwatch(seconds: 90)).value
        health.isOn = true
        await harness.launch().retryPending()

        #expect(harness.store.saved.isEmpty)
    }

    /// Only Workouts that end after the switch goes off are left out.
    @Test func `Turning saving off lets a save already pending finish`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified]
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90)).value
        health.isOn = false
        await health.retryPending()

        #expect(harness.store.saved.map(\.syncVersion) == [1, 2])
    }

    @Test(arguments: [HealthSaveOutcome.unverified, .failed])
    func `A save Health doesn't confirm is retried after a relaunch, with its version raised by 1`(
        outcome: HealthSaveOutcome
    ) async throws {
        let harness = try Harness()
        harness.store.outcomes = [outcome]
        let workoutID = UUID()

        await harness.launch().save(stopwatch(seconds: 90, workoutID: workoutID)).value
        await harness.launch().retryPending()
        await harness.launch().retryPending()

        #expect(harness.store.saved.map(\.syncVersion) == [1, 2])
        #expect(Set(harness.store.saved.map(\.syncIdentifier)) == [workoutID.uuidString])
        #expect(harness.store.saved.last == harness.store.saved.first?.withSyncVersion(2))
    }

    @Test func `A save is dropped after 3 attempts made with protected data available`() async throws {
        let harness = try Harness()
        harness.store.outcomes = Array(repeating: .unverified, count: 5)
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90)).value
        for _ in 1...3 {
            await health.retryPending()
        }

        #expect(harness.store.saved.map(\.syncVersion) == [1, 2, 3])
    }

    @Test func `An attempt while protected data is unavailable doesn't count toward the 3, and no retry runs then`()
        async throws
    {
        let harness = try Harness()
        harness.store.outcomes = Array(repeating: .unverified, count: 5)
        let health = harness.launch()
        harness.isProtectedDataAvailable = false

        await health.save(stopwatch(seconds: 90)).value
        await health.retryPending()
        harness.isProtectedDataAvailable = true
        for _ in 1...4 {
            await health.retryPending()
        }

        #expect(harness.store.saved.map(\.syncVersion) == [1, 2, 3, 4])
    }

    @Test func `A save Health refuses as not allowed is dropped`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.notAllowed]
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90)).value
        await health.retryPending()

        #expect(harness.store.saved.count == 1)
    }

    @Test func `A pending save is dropped once writing is no longer allowed`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified]
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90)).value
        harness.store.writeStatus = .denied
        await health.retryPending()
        harness.store.writeStatus = .allowed
        await health.retryPending()

        #expect(harness.store.saved.count == 1)
    }

    @Test func `Each Workout's save stands alone`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified, .saved]
        let health = harness.launch()
        let first = UUID()
        let second = UUID()

        await health.save(stopwatch(seconds: 90, workoutID: first)).value
        await health.save(stopwatch(seconds: 90, workoutID: second)).value
        await health.retryPending()
        await health.retryPending()

        #expect(harness.store.saved.map(\.syncIdentifier) == [first, second, first].map(\.uuidString))
        #expect(harness.store.saved.map(\.syncVersion) == [1, 1, 2])
    }

    @Test(arguments: [
        (HealthWriteStatus.notDetermined, HealthRequestStatus.shouldRequest, AppleHealthRow.saveWorkouts),
        (.allowed, .shouldRequest, .allowHeartRate),
        (.allowed, .unnecessary, .saving),
        (.denied, .shouldRequest, .notAllowed),
        (.denied, .unnecessary, .notAllowed),
    ])
    func `Settings shows the row for the write status and whether the full set would prompt`(
        writeStatus: HealthWriteStatus, requestStatus: HealthRequestStatus, row: AppleHealthRow
    ) async throws {
        let harness = try Harness()
        harness.store.writeStatus = writeStatus
        harness.store.requestStatus = requestStatus
        let health = harness.launch()
        #expect(health.row == nil)

        await health.refreshStatus()

        #expect(health.row == row)
    }

    @Test(arguments: [HealthRequestStatus.shouldRequest, .unnecessary])
    func `With workouts allowed and saving turned off, Settings shows the switch off`(
        requestStatus: HealthRequestStatus
    ) async throws {
        let harness = try Harness()
        harness.store.requestStatus = requestStatus
        let health = harness.launch()
        await health.refreshStatus()

        health.isOn = false

        #expect(health.row == .off)
    }

    @Test(arguments: [HealthWriteStatus.notDetermined, .denied])
    func `Until workouts are allowed, the switch being off changes nothing in Settings`(
        writeStatus: HealthWriteStatus
    ) async throws {
        let harness = try Harness()
        harness.store.writeStatus = writeStatus
        let health = harness.launch()
        await health.refreshStatus()
        let row = health.row

        health.isOn = false

        #expect(health.row == row)
    }

    /// "Allow Heart Rate" still saves workouts, so its footer keeps the saves sentence and adds what the Watch does.
    @Test(arguments: [
        (
            AppleHealthRow.saveWorkouts,
            "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch."
        ),
        (
            .allowHeartRate,
            "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch. "
                + "Apple Watch shows your heart rate and saves it to Health."
        ),
        (.saving, "Saves each Workout of 1 minute or more when it ends, with heart rate from Apple Watch."),
        (.off, "Workouts aren't saved to Health. Apple Watch still follows each one."),
        (.notAllowed, "Allow Temper under Settings › Health › Data Access & Devices."),
    ])
    func `Each row has its footer`(row: AppleHealthRow, footer: String) {
        #expect(row.footer == footer)
    }

    /// Anyone who allowed workouts in the shipped build is asked once more, and the row settles on the switch alone.
    @Test func `Asking for permission reads both statuses again`() async throws {
        let harness = try Harness()
        harness.store.requestStatus = .shouldRequest
        let health = harness.launch()
        await health.refreshStatus()
        try #require(health.row == .allowHeartRate)

        harness.store.duringPermissionRequest = { harness.store.requestStatus = .unnecessary }
        await health.requestPermission()

        #expect(harness.store.permissionRequests == 1)
        #expect(health.row == .saving)
    }
}
