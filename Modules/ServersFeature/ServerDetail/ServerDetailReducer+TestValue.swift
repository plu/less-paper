import ApiInterface
import Foundation

extension ServerDetailReducer.State {

    static func testValue(
        hasToken: Bool? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            server: server
        )
        state.hasToken = hasToken
        return state
    }
}
