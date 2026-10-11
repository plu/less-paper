import ApiInterface
import Foundation

extension ServerFormReducer.State {

    static func testValue(
        input: ServerFormInput = .testValue(),
        providers: [OIDCProvider] = [],
        selectedProvider: OIDCProvider? = nil
    ) -> Self {
        var state = Self(input: input)
        state.providers = providers
        state.selectedProvider = selectedProvider
        return state
    }
}
