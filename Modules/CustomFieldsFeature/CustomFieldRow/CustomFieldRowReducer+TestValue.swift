import ApiInterface
import Foundation

public extension CustomFieldRowReducer.State {

    static func testValue(
        customField: CustomField = .testValue(),
        isUpdating: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            customField: customField,
            isUpdating: isUpdating,
            server: server
        )
    }
}
