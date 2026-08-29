import Dependencies
import Logging
import StoreKit

extension TipJar: DependencyKey {

    public static let liveValue = Self(
        products: products,
        purchase: purchase(tip:),
        updates: updates
    )
}

private extension TipJar {

    // Ordered by Tip.allCases rather than by what StoreKit returns: the ladder is the point, and
    // StoreKit promises no order. A product missing from the answer - not yet approved, or pulled -
    // is dropped rather than faked.
    static func products() async throws -> [TipProduct] {
        let products = try await Product.products(for: Tip.allCases.map(\.rawValue))

        return Tip.allCases.compactMap { tip in
            guard let product = products.first(where: { $0.id == tip.rawValue }) else {
                return nil
            }

            return TipProduct(
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                tip: tip
            )
        }
    }

    static func purchase(tip: Tip) async throws -> TipPurchaseResult {
        @Dependency(\.log)
        var log

        guard let product = try await Product.products(for: [tip.rawValue]).first else {
            throw TipJarError.productUnavailable
        }

        switch try await product.purchase() {
        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await transaction.finish()
                return .success

            case let .unverified(transaction, error):
                await transaction.finish()
                log.error("tip \(tip.rawValue) failed verification: \(error.localizedDescription)", category: .tips)
                return .unverified
            }

        @unknown default:
            return .cancelled
        }
    }

    // Runs for the life of the app, not the life of the screen: an Ask to Buy approval can arrive
    // days after the sheet was dismissed, and an unfinished transaction comes back on every launch
    // until something finishes it.
    static func updates() -> AsyncStream<Tip> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    let transaction = switch verification {
                    case let .verified(transaction): transaction
                    case let .unverified(transaction, _): transaction
                    }

                    await transaction.finish()

                    if let tip = Tip(rawValue: transaction.productID) {
                        continuation.yield(tip)
                    }
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
