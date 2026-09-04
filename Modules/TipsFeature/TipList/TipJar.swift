import Dependencies
import DependenciesMacros
import Foundation

// What a row needs to show, and nothing else. The price is StoreKit's own formatted string, so a
// US storefront shows dollars rather than a euro figure converted by us.
public struct TipProduct: Equatable, Identifiable, Sendable {

    public let displayName: String

    public let displayPrice: String

    // The number behind displayPrice. Both are kept: the string is what a row renders, formatted by
    // StoreKit for the user's locale and currency, and rebuilding it from this would mean
    // reimplementing that formatting badly. This exists to be sorted on.
    public let price: Decimal

    public let tip: Tip

    public var id: Tip.ID { tip.id }

    public init(
        displayName: String,
        displayPrice: String,
        price: Decimal,
        tip: Tip
    ) {
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.tip = tip
    }
}

extension Array where Element == TipProduct {

    // Ascending by what the user is actually charged, rather than by the order the cases happen to
    // be declared in. Those agreed until someone repriced a product in App Store Connect without
    // touching the app - and because App Store prices are per-storefront, they could disagree in one
    // country and nowhere else, which is a bug that never reproduces locally.
    //
    // Ties fall back on declaration order because sorted(by:) is not stable: without it, two equally
    // priced tips could swap places between one call and the next.
    func sortedByPrice() -> [TipProduct] {
        sorted { left, right in
            guard left.price == right.price else {
                return left.price < right.price
            }
            return left.tip.rank < right.tip.rank
        }
    }
}

public enum TipPurchaseResult: Equatable, Sendable {

    // The user backed out of the sheet. They know what happened; the app says nothing.
    case cancelled

    // Ask to Buy: someone else has to approve it, and the transaction arrives later through
    // `updates` - possibly days later, with the app somewhere else entirely.
    case pending

    case success

    // The transaction failed StoreKit's signature check. It is still finished, because an
    // unfinished one is redelivered on every launch forever, and a tip grants nothing that a forged
    // transaction could steal.
    case unverified
}

@DependencyClient
public struct TipJar: Sendable {

    public var products: @Sendable () async throws -> [TipProduct] = { [] }

    public var purchase: @Sendable (_ tip: Tip) async throws -> TipPurchaseResult

    // Yields a tip only after its transaction has been finished, so nothing outside this client has
    // to remember to.
    public var updates: @Sendable () -> AsyncStream<Tip> = { AsyncStream { $0.finish() } }
}

extension TipJar: TestDependencyKey {

    public static let previewValue = Self(
        products: {
            [
                TipProduct(displayName: "Tiny tip", displayPrice: "€1.00", price: 1, tip: .tiny),
                TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small),
                TipProduct(displayName: "Medium tip", displayPrice: "€10.00", price: 10, tip: .medium),
                TipProduct(displayName: "Large tip", displayPrice: "€25.00", price: 25, tip: .large),
            ]
        },
        purchase: { _ in .success },
        updates: { AsyncStream { $0.finish() } }
    )

    public static let testValue = Self()
}

public extension DependencyValues {

    var tipJar: TipJar {
        get { self[TipJar.self] }
        set { self[TipJar.self] = newValue }
    }
}
