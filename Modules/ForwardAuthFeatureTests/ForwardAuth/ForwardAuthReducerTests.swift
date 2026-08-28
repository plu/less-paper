@testable import ForwardAuthFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@Suite
struct ForwardAuthReducerTests {

    // A bounce presents the login straight away and reports back as .signInFinished.
    @MainActor
    @Test
    func redirect_setsStateAndPresentsSignIn() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = TestStore(initialState: ForwardAuthReducer.State()) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthSignIn.present = { _ in true }
        }
        // The presenter and the release effect are covered by their own tests. Here we only care
        // about the state after .redirect.
        store.exhaustivity = .off

        await store.send(.redirect(redirect)) {
            $0.redirect = redirect
        }
        await store.receive(\.signInFinished)
    }

    // A second server bouncing while a login is up does not open a second sheet - but its parked
    // requests must be answered rather than left waiting for one. They error out and raise their
    // own login the next time they are tried.
    @MainActor
    @Test
    func redirect_whileOneIsPresented_dropsTheSecondServersWaiters() async {
        let first = ForwardAuthRedirect.testValue(
            server: .testValue(id: "first"),
            url: URL(string: "https://auth-1.example.com")!
        )
        let second = ForwardAuthRedirect.testValue(
            server: .testValue(id: "second"),
            url: URL(string: "https://auth-2.example.com")!
        )

        let coordinator = ForwardAuthCoordinator()
        let dropped = LockIsolated<Bool>(false)

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: first)
        ) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthCoordinator = coordinator
        }

        _ = await coordinator.redirects()

        // Park a request against the second server, so the effect has a waiter to answer.
        let parked = Task {
            let signedIn = await coordinator.awaitSignIn(for: second)
            dropped.setValue(!signedIn)
        }
        while await coordinator.waiterCount(for: second) == 0 {
            await Task.yield()
        }

        // State does not change: the presented login stays the one that is up.
        await store.send(.redirect(second))
        await parked.value

        #expect(dropped.value)
    }

    // Confirming the popup hands off to the presenter, which puts the login web view on top of
    // whatever is on screen. A sign-in that lands reports back as .signInFinished.
    @MainActor
    @Test
    func confirmed_presentsSignIn_andReportsSuccess() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthSignIn.present = { _ in true }
        }
        store.exhaustivity = .off

        await store.send(.confirmed(redirect))
        await store.receive(\.signInFinished)
    }

    // A closed browser is a decision: the presenter returns false and the flow cancels rather
    // than releasing the parked requests to be bounced again.
    @MainActor
    @Test
    func confirmed_presentsSignIn_andReportsCancellation() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthSignIn.present = { _ in false }
        }
        store.exhaustivity = .off

        await store.send(.confirmed(redirect))
        await store.receive(\.signInCancelled)
    }

    // A completed sign-in clears state and releases every request parked against that server;
    // each replays with the cookie now in app-group storage.
    @MainActor
    @Test
    func signInFinished_clearsStateAndReleasesWaiters() async {
        let redirect = ForwardAuthRedirect.testValue()
        let coordinator = ForwardAuthCoordinator()
        let signedIn = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthCoordinator = coordinator
        }
        store.exhaustivity = .off

        _ = await coordinator.redirects()

        let parked = Task {
            let result = await coordinator.awaitSignIn(for: redirect)
            signedIn.setValue(result)
        }
        while await coordinator.waiterCount(for: redirect) == 0 {
            await Task.yield()
        }

        await store.send(.signInFinished(redirect)) {
            $0.redirect = nil
        }
        await parked.value

        #expect(signedIn.value == true)
    }

    // A dismissed sheet clears the state the same way a completed one does, but answers the
    // parked requests with "do not replay": no cookie landed, so replaying would only be bounced
    // again. They error out, which is what the user asked for by dismissing.
    @MainActor
    @Test
    func signInCancelled_clearsStateAndDropsWaiters() async {
        let redirect = ForwardAuthRedirect.testValue()
        let coordinator = ForwardAuthCoordinator()
        let signedIn = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        } withDependencies: {
            $0.forwardAuthCoordinator = coordinator
        }
        store.exhaustivity = .off

        _ = await coordinator.redirects()

        let parked = Task {
            let result = await coordinator.awaitSignIn(for: redirect)
            signedIn.setValue(result)
        }
        while await coordinator.waiterCount(for: redirect) == 0 {
            await Task.yield()
        }

        await store.send(.signInCancelled(redirect)) {
            $0.redirect = nil
        }
        await parked.value

        #expect(signedIn.value == false)
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
