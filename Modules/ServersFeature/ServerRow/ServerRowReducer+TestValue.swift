import ApiInterface
import Foundation

extension ServerRowReducer.State {

    static func testValue(
        server: Server = .testValue()
    ) -> Self {
        .init(
            server: server
        )
    }
}
