@testable import TipsFeature

import Components
import ComposableArchitecture
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct TipListReducerTests {

    @Test
    func onAppear_loadsTheProducts() async {
        let products = [
            TipProduct(displayName: "Small tip", displayPrice: "€5.00", tip: .small),
            TipProduct(displayName: "Medium tip", displayPrice: "€10.00", tip: .medium),
        ]

        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.products = { products }
            }
        )

        await store.send(.view(.onAppear))
        await store.receive(\.productsLoaded) {
            $0.isLoading = false
            $0.products = products
        }
    }

    // An empty answer is a failure as far as the screen is concerned: a tip jar that renders as an
    // empty list reads as broken rather than as unavailable.
    @Test
    func onAppear_withNoProducts_showsTheFailureState() async {
        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.products = { [] }
            }
        )

        await store.send(.view(.onAppear))
        await store.receive(\.productsLoaded) {
            $0.isLoading = false
            $0.loadFailed = true
        }
    }

    @Test
    func onAppear_whenLoadingThrows_showsTheFailureState() async {
        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.products = { throw TestError.someError }
            }
        )

        await store.send(.view(.onAppear))
        await store.receive(\.productsFailed) {
            $0.isLoading = false
            $0.loadFailed = true
        }
    }

    @Test
    func retry_clearsTheFailureAndLoadsAgain() async {
        let store = TestStore(
            initialState: TipListReducer.State(isLoading: false, loadFailed: true),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.products = { [] }
            }
        )
        store.exhaustivity = .off

        await store.send(.view(.retryButtonTapped)) {
            $0.isLoading = true
            $0.loadFailed = false
        }
    }

    @Test
    func tipButtonTapped_purchasesAndThanks() async {
        let purchased = LockIsolated<[Tip]>([])
        let toasts = LockIsolated<[Toast]>([])

        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.purchase = { tip in
                    purchased.withValue { $0.append(tip) }
                    return .success
                }
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )

        await store.send(.view(.tipButtonTapped(.medium))) {
            $0.purchasingTip = .medium
        }
        await store.receive(\.purchaseResult) {
            $0.purchasingTip = nil
        }
        await store.finish()

        #expect(purchased.value == [.medium])
        #expect(toasts.value == [.success(String(localized: .tipThankYou))])
    }

    // A second tap while a purchase is in flight does nothing: StoreKit is already showing its
    // sheet, and a second one would queue behind it.
    @Test
    func tipButtonTapped_whileOneIsInFlight_isIgnored() async {
        let store = TestStore(
            initialState: TipListReducer.State(purchasingTip: .small),
            reducer: { TipListReducer() }
        )

        await store.send(.view(.tipButtonTapped(.large)))
    }

    // The user backed out. They know; saying so would be noise.
    @Test
    func cancelled_saysNothing() async {
        let toasts = LockIsolated<[Toast]>([])

        let store = TestStore(
            initialState: TipListReducer.State(purchasingTip: .small),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )

        await store.send(.purchaseResult(.cancelled)) {
            $0.purchasingTip = nil
        }
        await store.finish()

        #expect(toasts.value.isEmpty)
    }

    @Test
    func pendingAndUnverified_eachSayTheirOwnThing() async {
        let toasts = LockIsolated<[Toast]>([])

        let store = TestStore(
            initialState: TipListReducer.State(purchasingTip: .small),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )
        store.exhaustivity = .off

        await store.send(.purchaseResult(.pending))
        await store.send(.purchaseResult(.unverified))
        await store.finish()

        #expect(toasts.value == [
            .success(String(localized: .tipPending)),
            .error(String(localized: .tipFailed)),
        ])
    }
}
