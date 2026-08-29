import Components
import ComposableArchitecture

@Reducer
public struct TipListReducer: Sendable {

    @CasePathable
    public enum Action: ViewAction {

        case productsFailed

        case productsLoaded([TipProduct])

        case purchaseFailed(Error)

        case purchaseResult(TipPurchaseResult)

        case view(View)

        public enum View {
            case onAppear
            case retryButtonTapped
            case tipButtonTapped(Tip)
        }
    }

    @ObservableState
    public struct State: Equatable {

        var isLoading: Bool

        var loadFailed: Bool

        var products: [TipProduct]

        // Which row is waiting on StoreKit's sheet, so it can show a spinner and the others can
        // disable.
        var purchasingTip: Tip?

        public init(
            isLoading: Bool = true,
            loadFailed: Bool = false,
            products: [TipProduct] = [],
            purchasingTip: Tip? = nil
        ) {
            self.isLoading = isLoading
            self.loadFailed = loadFailed
            self.products = products
            self.purchasingTip = purchasingTip
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .productsFailed:
                state.isLoading = false
                state.loadFailed = true
                return .none

            case let .productsLoaded(products):
                state.isLoading = false
                // Nothing to show is a failure here, not an empty list: no network, StoreKit
                // unavailable, or products not approved yet all land on this line, and an empty
                // tip jar reads as broken.
                state.loadFailed = products.isEmpty
                state.products = products
                return .none

            // The one throw `purchase` documents rather than the catch-all `.unverified` others
            // land on: the product itself is gone, so the generic "something went wrong with that
            // tip" would be misleading about what the user could try next.
            case let .purchaseFailed(error):
                state.purchasingTip = nil
                return .toast(error)

            case let .purchaseResult(result):
                state.purchasingTip = nil
                switch result {
                case .cancelled:
                    return .none
                case .pending:
                    return .toast(Toast.success(String(localized: .tipPending)))
                case .success:
                    return .toast(Toast.success(String(localized: .tipThankYou)))
                case .unverified:
                    return .toast(Toast.error(String(localized: .tipFailed)))
                }

            case .view(.onAppear):
                // A re-appearance (a push/pop, or the app leaving and returning) must not
                // re-trigger the fetch once the screen already has an answer - otherwise
                // revisiting an already-failed or already-loaded screen flashes back to a blank
                // list while it silently refetches. `isLoading` starts `true`, so a fresh push
                // still loads; `retryButtonTapped` sets it back to `true` to force one.
                guard state.isLoading else {
                    return .none
                }
                state.loadFailed = false
                return .runLoadProducts()

            case .view(.retryButtonTapped):
                state.isLoading = true
                state.loadFailed = false
                return .runLoadProducts()

            case let .view(.tipButtonTapped(tip)):
                guard state.purchasingTip == nil else {
                    return .none
                }
                state.purchasingTip = tip
                return .runPurchase(tip: tip)
            }
        }
    }

    public init() {}
}
