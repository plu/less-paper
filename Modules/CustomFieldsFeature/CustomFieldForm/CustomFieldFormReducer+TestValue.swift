import ApiInterface
import Foundation

public extension CustomFieldFormReducer.State {

    static func testValue(
        customField: CustomField? = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            customField: customField,
            server: server
        )
    }
}
