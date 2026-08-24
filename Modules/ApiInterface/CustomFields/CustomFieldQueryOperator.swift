import Foundation

public enum CustomFieldQueryOperator: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case contains
    case exact
    case exists
    case gt
    case gte
    case icontains
    case `in`
    case isnull
    case lt
    case lte

    public var id: String {
        rawValue
    }

    // `gte`/`lte` are strings rather than numbers because the date group uses them for ISO dates
    // while the arithmetic group uses them for numbers. A string is the honest wire type for both,
    // and the editor picks its keyboard from the field's data type instead.
    public var valueKind: CustomFieldQueryValueKind {
        switch self {
        case .contains, .in:
            .array
        case .exists, .isnull:
            .boolean
        case .gt, .lt:
            .number
        case .exact, .gte, .icontains, .lte:
            .string
        }
    }

    public static func operators(for dataType: CustomFieldDataType) -> [Self] {
        var operators = [Self]()
        for group in CustomFieldQueryOperatorGroup.groups(for: dataType) {
            for queryOperator in group.operators where !operators.contains(queryOperator) {
                operators.append(queryOperator)
            }
        }
        return operators
    }
}

extension CustomFieldQueryOperator: CustomStringConvertible {
    public var description: String {
        switch self {
        case .contains:
            String(localized: .customFieldQueryOperatorContains)
        case .exact:
            String(localized: .customFieldQueryOperatorExact)
        case .exists:
            String(localized: .customFieldQueryOperatorExists)
        case .gt:
            String(localized: .customFieldQueryOperatorGt)
        case .gte:
            String(localized: .customFieldQueryOperatorGte)
        case .icontains:
            String(localized: .customFieldQueryOperatorIcontains)
        case .in:
            String(localized: .customFieldQueryOperatorIn)
        case .isnull:
            String(localized: .customFieldQueryOperatorIsnull)
        case .lt:
            String(localized: .customFieldQueryOperatorLt)
        case .lte:
            String(localized: .customFieldQueryOperatorLte)
        }
    }
}

public enum CustomFieldQueryValueKind: Equatable, Hashable, Sendable {
    case array
    case boolean
    case number
    case string
}
