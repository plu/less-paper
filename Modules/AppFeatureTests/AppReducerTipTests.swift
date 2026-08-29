@testable import AppFeature

import Components
import ComposableArchitecture
import Testing
import TestSupport
import TipsFeature

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerTipTests {

    // An Ask to Buy approval can arrive days after the sheet was dismissed, with the app anywhere.
    // The client has already finished the transaction by the time it reaches here; all that is left
    // is to say thank you.
    @Test
    func bootstrap_thanksForATipThatArrivesLate() async {
        let toasts = LockIsolated<[Toast]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.tipJar.updates = {
                    AsyncStream { continuation in
                        continuation.yield(.large)
                        continuation.finish()
                    }
                }
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )
        store.exhaustivity = .off

        await store.send(.bootstrap)
        await store.receive(\.tipReceived)
        await store.finish()

        #expect(toasts.value == [.success(String(localized: .tipThankYou))])
    }
}
