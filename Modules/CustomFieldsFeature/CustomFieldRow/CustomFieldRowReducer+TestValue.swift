import ApiInterface
import Foundation

public extension CustomFieldRowReducer.State {

    static func testValue(
        customField: CustomField = .testValue(),
        isUpdating: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            isUpdating: isUpdating,
            server: server,
            customField: customField
        )
    }
}
