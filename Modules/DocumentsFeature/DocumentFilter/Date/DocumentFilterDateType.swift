import ApiInterface
import Foundation

public enum DocumentFilterDateType: String, CaseIterable, Equatable, Sendable {
    case added
    case created

    var ruleTypes: [FilterRuleType] {
        [fromRuleType, toRuleType] + legacyRuleTypes
    }

    var fromRuleType: FilterRuleType {
        switch self {
        case .added:
            .addedFrom
        case .created:
            .createdFrom
        }
    }

    var toRuleType: FilterRuleType {
        switch self {
        case .added:
            .addedTo
        case .created:
            .createdTo
        }
    }

    var localized: LocalizedStringResource {
        switch self {
        case .added:
            .sortFieldAdded
        case .created:
            .sortFieldCreated
        }
    }

    private var legacyRuleTypes: [FilterRuleType] {
        switch self {
        case .added:
            [.addedAfter, .addedBefore]
        case .created:
            [.createdAfter, .createdBefore]
        }
    }
}

extension FilterRuleType {

    var isDateLowerBound: Bool {
        switch self {
        case .addedAfter, .addedFrom, .createdAfter, .createdFrom:
            true
        default:
            false
        }
    }

    var dateType: DocumentFilterDateType? {
        switch self {
        case .addedAfter, .addedBefore, .addedFrom, .addedTo:
            .added
        case .createdAfter, .createdBefore, .createdFrom, .createdTo:
            .created
        default:
            nil
        }
    }
}
