@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import ServersFeature
import TagsFeature
import Testing

@MainActor
@Suite
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
}
