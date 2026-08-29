@testable import AppFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerDeepLinkTests {

    // The link names the server that is already open: nothing to switch, so it applies at once.
    @Test
    func openURL_forTheSelectedServer_opensTheDocument() async {
        let server = Server.testValue(id: "1", url: URL(string: "https://paperless.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://paperless.example.com/documents/42/details")!))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)

        #expect(store.state.main?.selectedTab == .documents)
        #expect(store.state.pendingLink == nil)
    }

    // The link names another server. The selection changes, MainReducer.State is rebuilt for it,
    // and only then can the document be pushed - so the link has to wait rather than be dropped.
    @Test
    func openURL_forAnotherServer_waitsForTheSwitch() async {
        let current = Server.testValue(id: "1", url: URL(string: "https://one.example.com")!)
        let other = Server.testValue(id: "2", url: URL(string: "https://two.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [current, other]

        @Shared(.selectedServer)
        var selectedServer: Server? = current

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: current)),
            reducer: { AppReducer() },
            withDependencies: {
                // selectedServerChanged warms the cache for the server it switches to.
                $0.updateCache.execute = { _ in }
            }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://two.example.com/documents/42/details")!))

        #expect(store.state.pendingLink?.server.id == "2")
        #expect(selectedServer?.id == "2")

        // What the observer delivers once the selection has changed.
        await store.send(.selectedServerChanged(other))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)

        #expect(store.state.pendingLink == nil)
    }

    // A URL can arrive before servers have loaded at all. Held, not dropped.
    @Test
    func openURL_beforeAServerIsSelected_waits() async {
        let server = Server.testValue(id: "1", url: URL(string: "https://paperless.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.updateCache.execute = { _ in }
            }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(store.state.pendingLink?.server.id == "1")

        await store.send(.selectedServerChanged(server))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)
    }

    @Test
    func openURL_forAnUnknownHost_toastsAndHoldsNothing() async {
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [.testValue(url: URL(string: "https://paperless.example.com")!)]

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )

        await store.send(.openURL(URL(string: "lesspaper://stranger.example.com/documents/42/details")!))
        await store.finish()

        #expect(store.state.pendingLink == nil)
        #expect(toasts.value == [.error(DeepLinkError.serverNotFound(host: "stranger.example.com").localizedDescription)])
    }

    // atlp:// is also the OIDC callback scheme. That callback never reaches onOpenURL, but a URL
    // this app cannot read is not worth a toast either way - it says nothing the user can act on.
    @Test
    func openURL_thatIsNotADeepLink_isIgnored() async {
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() }
        )

        await store.send(.openURL(URL(string: "atlp://oidc-callback?code=c0ff33")!))

        #expect(store.state.pendingLink == nil)
    }
}
