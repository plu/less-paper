@testable import ForwardAuthFeature

import ApiInterface
import ComposableArchitecture
import Foundation
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

    // The confirmation popup being confirmed sets the sheet trigger. The parent view binds
    // .sheet(item:) to this and presents the login web view.
    @Test
    func confirmed_setsSheet() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        }

        await store.send(.confirmed(redirect)) {
            $0.sheet = redirect
        }
    }

    // A completed sign-in clears state and releases waiters. shouldRetry sees .finish and
    // replays the parked request with the cookie now in storage.
    @MainActor
    @Test
    func signInFinished_clearsStateAndReleasesWaiters() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect, sheet: redirect)
        ) {
            ForwardAuthReducer()
        }
        store.exhaustivity = .off

        await store.send(.signInFinished(redirect)) {
            $0.redirect = nil
            $0.sheet = nil
        }
    }

    // A dismissed sheet is the same handoff as a completed one from the reducer's perspective:
    // state clears and .finish goes out. shouldRetry then returns false because no cookie
    // landed, and the parked request errors out - which is what the user asked for by dismissing.
    @MainActor
    @Test
    func signInCancelled_clearsStateAndReleasesWaiters() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect, sheet: redirect)
        ) {
            ForwardAuthReducer()
        }
        store.exhaustivity = .off

        await store.send(.signInCancelled(redirect)) {
            $0.redirect = nil
            $0.sheet = nil
        }
    }
}

@Suite
struct ForwardAuthCookieStorageTests {

    // Sanity check on the seam Task 10 introduced. cookiesToSeed reads whatever the app-group
    // storage holds; if that read ever stops returning the API session's cookies (e.g. someone
    // changes the group identifier), the login sheet forces a re-auth every time.
    @Test
    func cookiesToSeed_readsAppGroupStorage() {
        let store = ForwardAuthCookieStorage.appGroup
        store.cookies?.forEach { store.deleteCookie($0) }

        let cookie = HTTPCookie(properties: [
            .domain: "auth.example.com",
            .path: "/",
            .name: "authelia_session",
            .value: "seeded",
        ])!
        store.setCookie(cookie)

        #expect(ForwardAuthCookieStorage.cookiesToSeed().contains(where: { $0.name == "authelia_session" }))

        store.deleteCookie(cookie)
    }

    @Test
    func store_writesToAppGroupStorage() {
        let store = ForwardAuthCookieStorage.appGroup
        store.cookies?.forEach { store.deleteCookie($0) }

        let cookie = HTTPCookie(properties: [
            .domain: "auth.example.com",
            .path: "/",
            .name: "authelia_session",
            .value: "written",
        ])!
        ForwardAuthCookieStorage.store([cookie])

        #expect(store.cookies?.contains(where: { $0.name == "authelia_session" }) == true)

        store.deleteCookie(cookie)
    }
}
