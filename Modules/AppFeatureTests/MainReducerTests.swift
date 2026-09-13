@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SettingsFeature
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct MainReducerTests {

    @Test
    func test_documentList_delegate_documentsDeleted_forwardsToInbox() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )

        await store.send(.documentList(.delegate(.documentsDeleted([7]))))
        await store.receive(\.inbox.documentsDeleted, [7])
    }

    @Test
    func test_inbox_delegate_documentsDeleted_forwardsToDocumentList() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )

        await store.send(.inbox(.delegate(.documentsDeleted([7]))))
        await store.receive(\.documentList.documentsDeleted, [7])
    }

    // The regression this guards: inbox and documentList each keep their own copy of
    // isTipInvitationVisible, and dismissing in one used to leave the other showing (and
    // tappable) a row the user had already answered, until its own onAppear caught up.
    @Test
    func test_documentList_tipInvitationDismissed_clearsInboxToo() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )
        store.exhaustivity = .off

        await store.send(.inbox(.tipInvitationEligible(true)))
        await store.send(.documentList(.view(.tipInvitationDismissed)))
        await store.receive(\.documentList.delegate, .tipInvitationSettled)
        await store.receive(\.inbox.tipInvitationEligible, false)
    }

    @Test
    func test_inbox_tipInvitationDismissed_clearsDocumentListToo() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )
        store.exhaustivity = .off

        await store.send(.documentList(.tipInvitationEligible(true)))
        await store.send(.inbox(.view(.tipInvitationDismissed)))
        await store.receive(\.inbox.delegate, .tipInvitationSettled)
        await store.receive(\.documentList.tipInvitationEligible, false)
    }

    @Test
    func test_selectedTab() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: MainReducer.State(server: server),
            reducer: { MainReducer() }
        )

        await store.send(.selectedTab(.settings)) {
            $0.selectedTab = .settings
        }
    }
}
