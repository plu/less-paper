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
    func path_pdfPasswordList_isReachable() async throws {
        let store = TestStore(initialState: SettingListReducer.State(server: .testValue())) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.path(.push(id: 0, state: .pdfPasswordList(PdfPasswordListReducer.State()))))

        #expect(store.state.path.count == 1)
    }
}
