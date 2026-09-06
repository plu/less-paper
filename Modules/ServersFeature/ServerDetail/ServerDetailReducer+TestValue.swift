import ApiInterface
import Foundation

extension ServerDetailReducer.State {

    static func testValue(
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server
        )
    }
}
