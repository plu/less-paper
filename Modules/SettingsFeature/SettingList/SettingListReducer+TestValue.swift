import ApiInterface
import Foundation

public extension SettingListReducer.State {
    static func testValue(
        server: Server = .testValue()
    ) -> Self {
        .init(server: server)
    }
}
