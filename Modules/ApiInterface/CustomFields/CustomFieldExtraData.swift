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

    private enum CodingKeys: String, CodingKey {
        case defaultCurrency, selectOptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultCurrency = try container.decodeIfPresent(String.self, forKey: .defaultCurrency)
        // paperless validates select_options only while the field is, or is becoming, a select;
        // everywhere else extra_data is an unvalidated JSON blob, so an option can arrive as null
        // or without a label. One such option would otherwise fail the whole /api/custom_fields/
        // page and leave the app with no custom fields at all.
        selectOptions = try container
            .decodeIfPresent([MaybeDecodable<CustomFieldSelectOption>].self, forKey: .selectOptions)?
            .compactMap(\.wrapped)
    }

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
