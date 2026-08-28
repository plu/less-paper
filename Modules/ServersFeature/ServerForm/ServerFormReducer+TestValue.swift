import ApiInterface
import Foundation

extension ServerFormReducer.State {

    static func testValue(
        input: ServerFormInput = .testValue(),
        providers: [OIDCProvider] = []
    ) -> Self {
        var state = Self(input: input)
        state.providers = providers
        return state
    }
}
