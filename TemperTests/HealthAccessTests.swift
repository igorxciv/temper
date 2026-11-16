import Testing

@testable import Temper

/// Stands in for HealthKit: it answers with the statuses it's given, and counts each request for permission.
private final class FakePermissionStore: HealthPermissionStore {
    var writeStatus: HealthWriteStatus = .allowed
    var requestStatus: HealthRequestStatus = .unnecessary
    private(set) var permissionRequests = 0

    /// Called when asked for permission, as the system sheet would be shown.
    var duringPermissionRequest: () -> Void = {}

    func requestPermission() async {
        permissionRequests += 1
        duringPermissionRequest()
    }
}

@MainActor
struct HealthAccessTests {
    @Test(arguments: [
        (HealthWriteStatus.notDetermined, HealthRequestStatus.shouldRequest, HeartRateRow.allowHeartRate),
        (.notDetermined, .unnecessary, .allowHeartRate),
        (.allowed, .shouldRequest, .allowHeartRate),
        (.allowed, .unnecessary, .allowed),
        (.denied, .shouldRequest, .notAllowed),
        (.denied, .unnecessary, .notAllowed),
    ])
    func `Settings shows the row for the write status and whether the full set would prompt`(
        writeStatus: HealthWriteStatus, requestStatus: HealthRequestStatus, row: HeartRateRow
    ) async {
        let store = FakePermissionStore()
        store.writeStatus = writeStatus
        store.requestStatus = requestStatus
        let health = HealthAccess(store: store)
        #expect(health.row == nil)

        await health.refreshStatus()

        #expect(health.row == row)
    }

    @Test(arguments: [
        (
            HeartRateRow.allowHeartRate,
            "Apple Watch shows your heart rate and Zone during a Workout. Temper saves nothing to Health."
        ),
        (.allowed, "Apple Watch shows your heart rate and Zone during a Workout. Temper saves nothing to Health."),
        (.notAllowed, "Allow Temper under Settings › Health › Data Access & Devices."),
    ])
    func `Each row has its footer`(row: HeartRateRow, footer: String) {
        #expect(row.footer == footer)
    }

    /// Anyone who allowed workouts in an earlier build is asked once more for the reads, and the row settles on the
    /// checkmark.
    @Test func `Asking for permission reads both statuses again`() async throws {
        let store = FakePermissionStore()
        store.requestStatus = .shouldRequest
        let health = HealthAccess(store: store)
        await health.refreshStatus()
        try #require(health.row == .allowHeartRate)

        store.duringPermissionRequest = { store.requestStatus = .unnecessary }
        await health.requestPermission()

        #expect(store.permissionRequests == 1)
        #expect(health.row == .allowed)
    }
}
