import ApiInterface
import ComposableArchitecture
import Foundation
@testable import ForwardAuthFeature
import Testing

@Suite
struct ForwardAuthReducerTests {

    @MainActor
    @Test
    func redirect_setsStateAndPresentsPopup() async {
        let store = TestStore(initialState: ForwardAuthReducer.State()) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthConfirmation.present = { _ in true }
        }
        // The presenter and the release effect are covered by their own tests. Here we only care
        // about the state after .redirect.
        store.exhaustivity = .off

        let redirect = ForwardAuthRedirect.testValue()

        await store.send(.redirect(redirect)) {
            $0.redirect = redirect
        }
    }

    // A .redirect arriving while one is presented is discarded. Ten concurrent bounces at launch
    // must produce one login, not ten.
    @Test
    func redirect_isIgnoredWhileOneIsAlreadyPresented() async {
        let first = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-1.example.com")!)
        let second = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-2.example.com")!)

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: first)
        ) {
            ForwardAuthReducer()
        }

        // The second .redirect is a no-op: state does not change, no effect fires.
        await store.send(.redirect(second))
    }

    // .finish for the same redirect clears the state so the next request can raise a fresh login.
    @Test
    func finish_clearsMatchingRedirect() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        }

        await store.send(.finish(redirect)) {
            $0.redirect = nil
        }
    }

    // .finish for a different redirect is ignored — the presented one still needs its own finish.
    @Test
    func finish_forDifferentRedirect_isIgnored() async {
        let presented = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-1.example.com")!)
        let other = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-2.example.com")!)

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: presented)
        ) {
            ForwardAuthReducer()
        }

        await store.send(.finish(other))
    }
}
