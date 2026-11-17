import Observation
import StoreKit

/// One tip as Settings offers it, named and priced by the App Store.
struct Tip: Identifiable, Equatable {
    let id: String
    let name: String
    let price: String
}

/// Settings' tip jar: three one-time tips that unlock nothing. With nothing to unlock there's no entitlement, receipt
/// check or Restore. Each tip's transaction is finished once it's verified, and Temper keeps nothing about it.
@Observable
final class TipJar {
    enum Shelf: Equatable {
        case loading
        case ready([Tip])
        /// Offline, or the App Store has no tips to offer.
        case unavailable
    }

    /// What the last tip came to, said in place. A cancel or a wait for Ask to Buy says nothing, and a new tip clears
    /// it.
    enum Outcome: Equatable {
        case thanks
        case failed
    }

    /// Plain IDs with no bundle prefix, so no personal ID is in the repo. App Store Connect's products use the same.
    static let productIDs = ["tip.small", "tip.medium", "tip.large"]

    private(set) var shelf = Shelf.loading
    private(set) var outcome: Outcome?
    /// The tip being bought, while the App Store's sheet is up, so another can't start under it.
    private(set) var purchasing: Tip.ID?

    @ObservationIgnored private var products: [Product.ID: Product] = [:]

    /// Loads the tips, smallest first. A failed load keeps what was shown, unless nothing was.
    func load() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            shelf =
                loaded.isEmpty
                ? .unavailable : .ready(loaded.map { Tip(id: $0.id, name: $0.displayName, price: $0.displayPrice) })
        } catch {
            // A load cut short as Temper leaves the front isn't a sign of being offline.
            if shelf == .loading, !Task.isCancelled {
                shelf = .unavailable
            }
        }
    }

    func tip(_ id: Tip.ID) async {
        guard purchasing == nil, let product = products[id] else { return }
        purchasing = id
        outcome = nil
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await finish(transaction)
            case .success(.unverified), .userCancelled, .pending:
                // An unverified tip may still have been charged, so it isn't called a failure.
                break
            @unknown default:
                break
            }
        } catch StoreKitError.userCancelled {
        } catch {
            outcome = .failed
        }
    }

    /// Finishes tips that arrive outside a tap, such as an approved Ask to Buy or one interrupted before it was
    /// finished. Runs for as long as Temper does, from launch.
    func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await finish(transaction)
            }
        }
    }

    /// Finishes a verified transaction, and thanks for it unless it's a refund.
    private func finish(_ transaction: Transaction) async {
        await transaction.finish()
        if transaction.revocationDate == nil, Self.productIDs.contains(transaction.productID) {
            outcome = .thanks
        }
    }
}
