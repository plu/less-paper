import Foundation

public struct CustomFieldExtraData: Codable, Equatable, Hashable, Sendable {

    public let defaultCurrency: String?

    public let selectOptions: [CustomFieldSelectOption]?

    public init(
        defaultCurrency: String? = nil,
        selectOptions: [CustomFieldSelectOption]? = nil
    ) {
        self.defaultCurrency = defaultCurrency
        self.selectOptions = selectOptions
    }
}

public extension CustomFieldExtraData {

    static func testValue(
        defaultCurrency: String? = nil,
        selectOptions: [CustomFieldSelectOption]? = nil
    ) -> Self {
        .init(
            defaultCurrency: defaultCurrency,
            selectOptions: selectOptions
        )
    }
}
