@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct ProviderLoadingTests {

    @Test
    func test_changingTheUrl_asksTheServerWhatItOffers() async {
        let clock = TestClock()
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.oidcClient.providers = { _ in [.testValue()] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.input.url, URL(string: "http://paperless.example.com")!)))
        await clock.advance(by: .milliseconds(600))

        await store.receive(\.loadProviders)
        await store.receive(\.providersLoaded) {
            $0.providers = [.testValue()]
        }
    }
}
