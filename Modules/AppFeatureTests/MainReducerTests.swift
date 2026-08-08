@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SettingsFeature
import Testing

@MainActor
@Suite
struct MainReducerTests {

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
