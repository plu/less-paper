import ApiInterface
import Foundation

/// Which of a document's dates the date filter constrains.
public enum DocumentFilterDateType: String, CaseIterable, Equatable, Sendable {
    case added
    case created

    /// The rule types this date belongs to, in both the modern inclusive and legacy exclusive
    /// spellings Paperless accepts.
    var ruleTypes: [FilterRuleType] {
        [fromRuleType, toRuleType] + legacyRuleTypes
    }

    /// The rule written for a lower bound the user has just set.
    ///
    /// The modern inclusive spelling: picking a date includes documents dated that day, which is
    /// what a date picker implies. A bound parsed from a saved view keeps whatever spelling that
    /// view used instead.
    var fromRuleType: FilterRuleType {
        switch self {
        case .added:
            .addedFrom
        case .created:
            .createdFrom
        }
    }

    /// The rule written for an upper bound the user has just set.
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

    /// The exclusive spellings, kept only so a saved view built with them round-trips unchanged.
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

    /// Whether this rule is a lower bound (`__gte` / `__gt`) rather than an upper one.
    var isDateLowerBound: Bool {
        switch self {
        case .addedAfter, .addedFrom, .createdAfter, .createdFrom:
            true
        default:
            false
        }
    }

    /// The date this rule constrains, or `nil` if it is not a from/to date rule.
    ///
    /// `createdYear`, `createdMonth`, `createdDay` and the `modified` rules are deliberately absent
    /// — they are not from/to bounds, so they keep passing through untouched.
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
