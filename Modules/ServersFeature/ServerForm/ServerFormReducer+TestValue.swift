import ApiInterface
import Foundation

extension ServerFormReducer.State {

    static func testValue(
        input: ServerFormInput = .testValue(),
        isPasswordlessEdit: Bool = false,
        providers: [OIDCProvider] = [],
        selectedProvider: OIDCProvider? = nil
    ) -> Self {
        var state = Self(input: input, isPasswordlessEdit: isPasswordlessEdit)
        state.providers = providers
        state.selectedProvider = selectedProvider
        return state
    }
}
