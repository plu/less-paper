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
