@testable import TipsFeature

import Components
import ComposableArchitecture
import Logging
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
            TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small),
            TipProduct(displayName: "Medium tip", displayPrice: "€10.00", price: 10, tip: .medium),
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

    // A re-appearance (a push/pop, or the app leaving and returning) must not re-trigger the
    // fetch once the screen already has an answer - otherwise revisiting an already-failed screen
    // flashes back to a blank list while it silently refetches.
    @Test
    func onAppear_whenAlreadyResolved_doesNothing() async {
        let store = TestStore(
            initialState: TipListReducer.State(isLoading: false, loadFailed: true),
            reducer: { TipListReducer() }
        )

        await store.send(.view(.onAppear))
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

    // A user reporting "Tips are unavailable" leaves Diagnostics as the only place to look, so the
    // failure has to reach the log, not just the screen.
    @Test
    func onAppear_whenLoadingThrows_showsTheFailureStateAndLogsIt() async {
        let logged = LockIsolated<[(message: String, category: LogCategory)]>([])

        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.products = { throw TestError.someError }
                $0.log.record = { message, _, category in
                    logged.withValue { $0.append((message, category)) }
                }
            }
        )

        await store.send(.view(.onAppear))
        await store.receive(\.productsFailed) {
            $0.isLoading = false
            $0.loadFailed = true
        }

        #expect(logged.value.count == 1)
        #expect(logged.value.first?.category == .tips)
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
                // A tip also asks for a review, and that waits a beat for the StoreKit sheet to go
                // away before it does.
                $0.continuousClock = ImmediateClock()
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

    // The product being gone is the one throw `purchase` documents, and it reads a lot less
    // helpfully as "something went wrong with that tip" than as its own message.
    @Test
    func tipButtonTapped_whenProductUnavailable_showsItsOwnMessage() async {
        let logged = LockIsolated<[LogCategory]>([])
        let toasts = LockIsolated<[Toast]>([])

        let store = TestStore(
            initialState: TipListReducer.State(),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.tipJar.purchase = { _ in throw TipJarError.productUnavailable }
                $0.log.record = { _, _, category in
                    logged.withValue { $0.append(category) }
                }
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )

        await store.send(.view(.tipButtonTapped(.small))) {
            $0.purchasingTip = .small
        }
        await store.receive(\.purchaseFailed) {
            $0.purchasingTip = nil
        }
        await store.finish()

        #expect(logged.value == [.tips])
        #expect(toasts.value == [.error(String(localized: .tipProductUnavailable))])
    }

    // Money given for nothing in return is the one unambiguous "I like this" the app can observe.
    // It is asked for here rather than from the tip observer in AppReducer, which also fires at
    // launch when StoreKit redelivers an old transaction - putting the prompt in front of someone
    // who has just opened the app and done nothing.
    @Test
    func purchaseSucceeded_asksForAReview() async {
        let moments = LockIsolated<[ReviewMoment]>([])

        let store = TestStore(
            initialState: TipListReducer.State(purchasingTip: .small),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.continuousClock = ImmediateClock()
                $0.reviewPrompt.record = { moment in moments.withValue { $0.append(moment) } }
                $0.toastPresenter.present = { _ in }
            }
        )

        await store.send(.purchaseResult(.success)) {
            $0.purchasingTip = nil
        }
        await store.finish()

        #expect(moments.value == [.tipReceived])
    }

    @Test
    func purchaseCancelled_asksForNothing() async {
        let moments = LockIsolated<[ReviewMoment]>([])

        let store = TestStore(
            initialState: TipListReducer.State(purchasingTip: .small),
            reducer: { TipListReducer() },
            withDependencies: {
                $0.reviewPrompt.record = { moment in moments.withValue { $0.append(moment) } }
            }
        )

        await store.send(.purchaseResult(.cancelled)) {
            $0.purchasingTip = nil
        }
        await store.finish()

        #expect(moments.value.isEmpty)
    }
}
