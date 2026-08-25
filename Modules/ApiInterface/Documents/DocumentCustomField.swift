import Foundation
import Tagged

public struct DocumentCustomField: Codable, Equatable, Hashable, Sendable {

    public let field: CustomField.Id

    public let value: JSONValue

    public init(
        field: CustomField.Id,
        value: JSONValue
    ) {
        self.field = field
        self.value = value
    }
}

public extension DocumentCustomField {

    static func testValue(
        field: CustomField.Id = 1,
        value: JSONValue = .string("Test")
    ) -> Self {
        .init(
            field: field,
            value: value
        )
    }
}
