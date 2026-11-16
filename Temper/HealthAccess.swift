import Observation

/// Temper's Health permission, as Settings shows it, and the one place it's asked for. The one request covers
/// everything the Watch will need, so the Watch never asks. Temper saves nothing to Health.
@Observable
final class HealthAccess {
    /// Settings' Heart Rate row, from the statuses as last read, or `nil` before the first read.
    private(set) var row: HeartRateRow?

    @ObservationIgnored private let store: any HealthPermissionStore

    init(store: any HealthPermissionStore = HealthKitPermissions()) {
        self.store = store
    }

    func refreshStatus() async {
        let requestStatus = await store.requestStatus
        row = HeartRateRow(writeStatus: store.writeStatus, requestStatus: requestStatus)
    }

    func requestPermission() async {
        await store.requestPermission()
        await refreshStatus()
    }
}
