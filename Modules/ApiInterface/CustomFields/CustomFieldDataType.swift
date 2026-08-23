import Foundation

public enum CustomFieldDataType: String, Codable, Hashable, Sendable {
    case boolean
    case date
    case documentLink = "documentlink"
    case float
    case integer
    case longText = "longtext"
    case monetary
    case select
    case string
    case unknown
    case url
}

public extension CustomFieldDataType {

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try CustomFieldDataType(rawValue: container.decode(String.self)) ?? .unknown
    }
}

extension CustomFieldDataType: CaseIterable {

    // Hand-written, in the order the server lists its choices, and deliberately without `unknown`:
    // `MenuField` builds its picker straight from `allCases`, so a case in here is a case the user
    // can pick, and `unknown` is only ever a decoding fallback.
    public static let allCases: [CustomFieldDataType] = [
        .string,
        .url,
        .date,
        .boolean,
        .integer,
        .float,
        .monetary,
        .documentLink,
        .select,
        .longText
    ]
}

extension CustomFieldDataType: Identifiable {
    public var id: String {
        rawValue
    }
}

extension CustomFieldDataType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .boolean:
            String(localized: .customFieldDataTypeBoolean)
        case .date:
            String(localized: .customFieldDataTypeDate)
        case .documentLink:
            String(localized: .customFieldDataTypeDocumentLink)
        case .float:
            String(localized: .customFieldDataTypeFloat)
        case .integer:
            String(localized: .customFieldDataTypeInteger)
        case .longText:
            String(localized: .customFieldDataTypeLongText)
        case .monetary:
            String(localized: .customFieldDataTypeMonetary)
        case .select:
            String(localized: .customFieldDataTypeSelect)
        case .string:
            String(localized: .customFieldDataTypeString)
        case .unknown:
            String(localized: .customFieldDataTypeUnknown)
        case .url:
            String(localized: .customFieldDataTypeUrl)
        }
    }
}
