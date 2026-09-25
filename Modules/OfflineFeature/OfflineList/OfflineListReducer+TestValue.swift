import ApiInterface
import Foundation

extension OfflineListReducer.State {

    static func testValue(server: Server = .testValue()) -> Self {
        .init(server: server)
    }
}
