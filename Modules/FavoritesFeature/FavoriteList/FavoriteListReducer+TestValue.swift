import ApiInterface
import Foundation

extension FavoriteListReducer.State {

    static func testValue(server: Server = .testValue()) -> Self {
        .init(server: server)
    }
}
