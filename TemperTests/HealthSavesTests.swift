import Foundation
import TemperCore
import Testing

@testable import Temper

/// Stands in for HealthKit: it answers with the write status and outcomes it's given, and keeps every record it was
/// asked to save.
private final class FakeHealthStore: HealthWorkoutStore {
    var writeStatus: HealthWriteStatus = .allowed
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

    /// What every adapter launched here wrote to the timing log, in order.
    private(set) var logged: [HealthAttemptResult] = []

    /// A Health adapter as Temper makes one at launch, over the same defaults each time.
    func launch() -> HealthSaves {
        let health = HealthSaves(store: store, defaults: defaults) { [unowned self] in isProtectedDataAvailable }
        health.didLog = { [unowned self] in logged.append($0) }
        return health
    }
}

private let start = ContinuousClock.now
private let startDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// A Stopwatch's Work that ran for `seconds` from Start, with no Prepare.
private func stopwatch(seconds: Int) -> WorkoutRecord<ContinuousClock.Instant> {
    let end = start + .seconds(seconds)
    return WorkoutRecord(
        start: start, end: end, pauses: [],
        phases: [.init(kind: .work, round: nil, start: start, end: end)]
    )
}

@MainActor
struct HealthSavesTests {
    @Test func `An ended Workout of a minute or more is saved once, and leaves nothing pending`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        let workoutID = UUID()

        await health.save(stopwatch(seconds: 60), of: .stopwatch, workoutID: workoutID, at: start, date: startDate)
            .value

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

        let saving = harness.launch().save(
            stopwatch(seconds: 90), of: .stopwatch, workoutID: workoutID, at: start, date: startDate)

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

        await harness.launch().save(
            stopwatch(seconds: 90), of: .stopwatch, workoutID: workoutID, at: start, date: startDate
        )
        .value

        #expect(storedDuringSave == 2)
    }

    @Test func `A retry while an attempt is under way doesn't save the same Workout again`() async throws {
        let harness = try Harness()
        let health = harness.launch()
        harness.store.duringSave = { [unowned store = harness.store, unowned health] _ in
            guard store.saved.count == 1 else { return }
            await health.retryPending()
        }

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value

        #expect(harness.store.saved.map(\.syncVersion) == [1])
    }

    @Test func `A Workout of less than a minute saves nothing`() async throws {
        let harness = try Harness()

        await harness.launch().save(
            stopwatch(seconds: 59), of: .stopwatch, workoutID: UUID(), at: start, date: startDate
        )
        .value

        #expect(harness.store.saved.isEmpty)
    }

    @Test(arguments: [HealthWriteStatus.notDetermined, .denied])
    func `Unless writing is allowed, an ended Workout saves nothing and leaves nothing to retry`(
        status: HealthWriteStatus
    ) async throws {
        let harness = try Harness()
        harness.store.writeStatus = status

        await harness.launch().save(
            stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate
        )
        .value
        harness.store.writeStatus = .allowed
        await harness.launch().retryPending()

        #expect(harness.store.saved.isEmpty)
    }

    @Test(arguments: [HealthSaveOutcome.unverified, .failed])
    func `A save Health doesn't confirm is retried after a relaunch, with its version raised by 1`(
        outcome: HealthSaveOutcome
    ) async throws {
        let harness = try Harness()
        harness.store.outcomes = [outcome]
        let workoutID = UUID()

        await harness.launch().save(
            stopwatch(seconds: 90), of: .stopwatch, workoutID: workoutID, at: start, date: startDate
        )
        .value
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

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value
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

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value
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

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value
        await health.retryPending()

        #expect(harness.store.saved.count == 1)
    }

    @Test func `A pending save is dropped once writing is no longer allowed`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified]
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value
        harness.store.writeStatus = .denied
        await health.retryPending()
        harness.store.writeStatus = .allowed
        await health.retryPending()

        #expect(harness.store.saved.count == 1)
    }

    @Test(arguments: [
        (HealthSaveOutcome.saved, HealthAttemptResult.saved), (.unverified, .unverified), (.failed, .failed),
        (.notAllowed, .dropped),
    ])
    func `Each attempt writes one line to the timing log`(outcome: HealthSaveOutcome, logged: HealthAttemptResult)
        async throws
    {
        let harness = try Harness()
        harness.store.outcomes = [outcome]

        await harness.launch().save(
            stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate
        )
        .value

        #expect(harness.logged == [logged])
    }

    @Test func `The attempt that uses up the 3 logs only that it dropped the save`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified, .failed, .unverified]
        let health = harness.launch()

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: UUID(), at: start, date: startDate).value
        await health.retryPending()
        await health.retryPending()

        #expect(harness.logged == [.unverified, .failed, .dropped])
    }

    @Test func `Each Workout's save stands alone`() async throws {
        let harness = try Harness()
        harness.store.outcomes = [.unverified, .saved]
        let health = harness.launch()
        let first = UUID()
        let second = UUID()

        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: first, at: start, date: startDate).value
        await health.save(stopwatch(seconds: 90), of: .stopwatch, workoutID: second, at: start, date: startDate).value
        await health.retryPending()
        await health.retryPending()

        #expect(harness.store.saved.map(\.syncIdentifier) == [first, second, first].map(\.uuidString))
        #expect(harness.store.saved.map(\.syncVersion) == [1, 1, 2])
    }

    @Test func `Asking for permission reads the write status again`() async throws {
        let harness = try Harness()
        harness.store.writeStatus = .notDetermined
        let health = harness.launch()
        health.refreshStatus()
        #expect(health.writeStatus == .notDetermined)

        harness.store.duringPermissionRequest = { harness.store.writeStatus = .allowed }
        await health.requestPermission()

        #expect(harness.store.permissionRequests == 1)
        #expect(health.writeStatus == .allowed)
    }
}
