import Dependencies
import DependenciesMacros

// What a row needs to show, and nothing else. The price is StoreKit's own formatted string, so a
// US storefront shows dollars rather than a euro figure converted by us.
public struct TipProduct: Equatable, Identifiable, Sendable {

    public let displayName: String

    public let displayPrice: String

    public let tip: Tip

    public var id: Tip.ID { tip.id }

    public init(
        displayName: String,
        displayPrice: String,
        tip: Tip
    ) {
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.tip = tip
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
                TipProduct(displayName: "Small tip", displayPrice: "€5.00", tip: .small),
                TipProduct(displayName: "Medium tip", displayPrice: "€10.00", tip: .medium),
                TipProduct(displayName: "Large tip", displayPrice: "€25.00", tip: .large),
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
