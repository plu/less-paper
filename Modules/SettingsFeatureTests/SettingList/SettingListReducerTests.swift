@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import PdfPasswordsFeature
import ServersFeature
import TagsFeature
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct SettingListReducerTests {

    @Test
    func test_path_push_serverList() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: SettingListReducer.State(server: server),
            reducer: { SettingListReducer() }
        )

        await store.send(.path(.push(id: 0, state: .serverList(ServerListReducer.State())))) {
            $0.path.append(.serverList(ServerListReducer.State()))
        }
    }

    @Test
    func test_path_push_tagList() async {
        let server = Server.testValue()
        let store = TestStore(
            initialState: SettingListReducer.State(server: server),
            reducer: { SettingListReducer() }
        )

        await store.send(.path(.push(id: 0, state: .tagList(TagListReducer.State(server: server))))) {
            $0.path.append(.tagList(TagListReducer.State(server: server)))
        }
    }

    @Test
    func importAndScanRowsOpenWithAddDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.addDocument] }

        let state = SettingListReducer.State(server: server)

        // Settings carries a second copy of Import and Scan, gated the same way the list toolbar
        // is; the snapshot covers only their absence.
        #expect(state.canImport)
        #expect(state.canScan)
        // The neighbour check: the Trash row answers to delete_document, not to add_document.
        #expect(!state.canViewTrash)
    }

    @Test
    func path_pdfPasswordList_isReachable() async throws {
        let store = TestStore(initialState: SettingListReducer.State(server: .testValue())) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.path(.push(id: 0, state: .pdfPasswordList(PdfPasswordListReducer.State()))))

        #expect(store.state.path.count == 1)
    }
}
