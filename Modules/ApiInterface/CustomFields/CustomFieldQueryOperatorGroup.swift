import Foundation

public enum CustomFieldQueryOperatorGroup: String, CaseIterable, Hashable, Sendable {
    case arithmetic
    case basic
    case containment
    case date
    case exact
    case string
    case subset

    public var operators: [CustomFieldQueryOperator] {
        switch self {
        case .arithmetic:
            [.gt, .gte, .lt, .lte]
        case .basic:
            [.exists, .isnull]
        case .containment:
            [.contains]
        case .date:
            [.gte, .lte]
        case .exact:
            [.exact]
        case .string:
            [.icontains]
        case .subset:
            [.in]
        }
    }

    // Mirrors CUSTOM_FIELD_QUERY_OPERATOR_GROUPS_BY_TYPE in the paperless-ngx web client. `unknown`
    // is a decoding fallback rather than a type the server has, so it admits nothing and the UI
    // offers no condition for such a field.
    public static func groups(for dataType: CustomFieldDataType) -> [Self] {
        switch dataType {
        case .boolean:
            [.basic, .exact]
        case .date:
            [.basic, .exact, .date]
        case .documentLink:
            [.basic, .containment]
        case .float, .integer:
            [.basic, .exact, .arithmetic]
        case .longText:
            [.basic, .string]
        case .monetary:
            [.basic, .exact, .string, .arithmetic]
        case .select:
            [.basic, .exact, .subset]
        case .string, .url:
            [.basic, .exact, .string]
        case .unknown:
            []
        }
    }
}
