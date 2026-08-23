import Foundation
import Tagged

public typealias GetCustomFieldsOutput = ListOutput<CustomField, CustomField.Id>

public extension ListOutput where Element == CustomField, Id == CustomField.Id {

    static func testValue(
        count: Int = 0,
        next: URL? = nil,
        results: [Element] = []
    ) -> Self {
        .init(
            count: count,
            next: next,
            results: results
        )
    }
}
