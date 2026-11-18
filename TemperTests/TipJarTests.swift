import Foundation
import StoreKit
import StoreKitTest
import Testing

@testable import Temper

/// Runs the tip jar against `Temper.storekit` through a local StoreKit test session. The session is one per process,
/// so these tests run one at a time. CI skips them: StoreKit testing on a new Simulator often gets no products, and
/// every CI run starts on one.
@MainActor
@Suite(
    .serialized,
    .disabled(
        if: ProcessInfo.processInfo.environment["TEMPER_SKIP_STOREKIT_TESTS"] != nil,
        "StoreKit testing is unreliable on CI's new Simulators"))
struct TipJarTests {
    /// Read from beside this file, since a buildable folder doesn't copy a `.storekit` into the bundle. The Simulator
    /// reads the Mac's files, so the path holds there.
    private static let configuration = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "Temper.storekit")

    private let session: SKTestSession

    init() async throws {
        session = try SKTestSession(contentsOf: Self.configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        // `clearTransactions()` leaves a purchase that completed after an earlier run stopped, such as CI's warm-up,
        // unfinished, and it would read as this run's.
        for await transaction in Transaction.unfinished {
            await transaction.unsafePayloadValue.finish()
        }
    }

    @Test func `The tips load smallest first, priced by the App Store`() async {
        let jar = TipJar()

        await jar.load()

        #expect(
            jar.shelf
                == .ready([
                    Tip(id: "tip.small", name: "Small Tip", price: "$1.99"),
                    Tip(id: "tip.medium", name: "Medium Tip", price: "$4.99"),
                    Tip(id: "tip.large", name: "Large Tip", price: "$9.99"),
                ]))
    }

    @Test func `Without a connection the tips are unavailable`() async throws {
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let jar = TipJar()

        await jar.load()

        #expect(jar.shelf == .unavailable)
    }

    @Test func `A tip says thank you, and its transaction is finished`() async throws {
        let start = Date.now
        let jar = TipJar()
        await jar.load()

        await jar.tip("tip.medium")

        #expect(jar.outcome == .thanks)
        await expectFinished("tip.medium", since: start)
    }

    @Test func `Cancelling a tip leaves the tip jar as it was`() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let jar = TipJar()
        await jar.load()
        let shelf = jar.shelf

        await jar.tip("tip.small")

        // iOS 27.0's test session reports every simulated error as `.unknown`, so a cancel can't be told apart there.
        withKnownIssue("A simulated cancel arrives as StoreKitError.unknown before iOS 27.2") {
            #expect(jar.outcome == nil)
        } when: {
            !ProcessInfo.processInfo.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0))
        }
        #expect(jar.shelf == shelf)
    }

    /// A tip waiting on Ask to Buy says nothing yet. If it's approved, it arrives later as a transaction update.
    @Test func `A tip waiting on Ask to Buy leaves the tip jar as it was`() async {
        session.askToBuyEnabled = true
        let jar = TipJar()
        await jar.load()

        await jar.tip("tip.large")

        #expect(jar.outcome == nil)
        #expect(session.allTransactions().contains { $0.pendingAskToBuyConfirmation })
    }

    @Test func `A tip that fails says it didn't go through`() async throws {
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let jar = TipJar()
        await jar.load()

        await jar.tip("tip.small")

        #expect(jar.outcome == .failed)
    }

    /// An approved Ask to Buy, or a purchase interrupted earlier, arrives as an update rather than from the tap.
    @Test(.timeLimit(.minutes(1)))
    func `A tip that arrives later says thank you, and its transaction is finished`() async throws {
        let start = Date.now
        let jar = TipJar()
        let updates = Task { await jar.observeTransactionUpdates() }
        defer { updates.cancel() }

        try await session.buyProduct(identifier: "tip.small")

        for await outcome in Observations({ jar.outcome }) where outcome == .thanks {
            break
        }
        await expectFinished("tip.small", since: start)
    }

    /// Expects no unfinished transaction for the tip this test bought. Only its own count, since one from an earlier
    /// run can complete late, as CI's warm-up can leave one.
    private func expectFinished(
        _ productID: String, since start: Date, sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        var unfinished: [Transaction] = []
        for await transaction in Transaction.unfinished {
            unfinished.append(transaction.unsafePayloadValue)
        }
        // A second's margin, in case a purchase date is kept to whole seconds.
        let mine = unfinished.filter { $0.productID == productID && $0.purchaseDate >= start.addingTimeInterval(-1) }
        #expect(
            mine.isEmpty, "Unfinished: \(unfinished.map { "\($0.productID) at \($0.purchaseDate)" })",
            sourceLocation: sourceLocation)
    }
}
