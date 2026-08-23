import Foundation

public struct CustomFieldSelectOption: Codable, Equatable, Hashable, Sendable {

    public let id: String?

    public let label: String

    public init(
        id: String? = nil,
        label: String
    ) {
        self.id = id
        self.label = label
    }
}

public extension CustomFieldSelectOption {

    static func testValue(
        id: String? = "aqgT3m4XZw8aw3Ou",
        label: String = "Open"
    ) -> Self {
        .init(
            id: id,
            label: label
        )
    }
}
