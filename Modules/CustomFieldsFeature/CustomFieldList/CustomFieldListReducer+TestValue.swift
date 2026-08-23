import ApiInterface
import Foundation
import IdentifiedCollections

extension CustomFieldListReducer.State {

    static func testValue(
        customFields: [CustomField] = [],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            customFields: IdentifiedArray(
                uniqueElements: customFields.map {
                    CustomFieldRowReducer.State(
                        customField: $0,
                        server: server
                    )
                }
            ),
            isLoaded: isLoaded,
            server: server
        )
    }
}
