import ApiInterface
import Foundation

extension MainReducer.State {

    static func testValue(
        selectedTab: AppTab = .settings,
        server: Server = .testValue()
    ) -> Self {
        .init(
            selectedTab: selectedTab,
            server: server
        )
    }
}
