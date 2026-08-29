import ComposableArchitecture

extension Effect where Action == TipListReducer.Action {

    static func runLoadProducts() -> Self {
        @Dependency(\.tipJar.products)
        var products

        return .run { send in
            await send(.productsLoaded(try await products()))
        } catch: { _, send in
            await send(.productsFailed)
        }
    }

    static func runPurchase(tip: Tip) -> Self {
        @Dependency(\.tipJar.purchase)
        var purchase

        return .run { send in
            await send(.purchaseResult(try await purchase(tip)))
        } catch: { _, send in
            // A throw here is the product being unavailable, which the user can do nothing about
            // and which reads the same as any other failed tip.
            await send(.purchaseResult(.unverified))
        }
    }
}
