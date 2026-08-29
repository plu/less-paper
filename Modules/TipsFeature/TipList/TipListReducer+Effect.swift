import ComposableArchitecture
import Logging

extension Effect where Action == TipListReducer.Action {

    static func runLoadProducts() -> Self {
        @Dependency(\.tipJar.products)
        var products

        return .run { send in
            await send(.productsLoaded(try await products()))
        } catch: { error, send in
            @Dependency(\.log)
            var log
            log.error(error, category: .tips)
            await send(.productsFailed)
        }
    }

    static func runPurchase(tip: Tip) -> Self {
        @Dependency(\.tipJar.purchase)
        var purchase

        return .run { send in
            await send(.purchaseResult(try await purchase(tip)))
        } catch: { error, send in
            @Dependency(\.log)
            var log
            log.error(error, category: .tips)

            // The product being gone is the one throw worth naming to the user; anything else
            // reads the same as any other failed tip.
            if case TipJarError.productUnavailable = error {
                await send(.purchaseFailed(error))
            } else {
                await send(.purchaseResult(.unverified))
            }
        }
    }
}
