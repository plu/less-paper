import ApiInterface
import Foundation
import IdentifiedCollections

extension CustomFieldQuery {

    func summary(fields: IdentifiedArrayOf<CustomField>) -> String {
        switch self {
        case let .atom(atom):
            atom.summary(fields: fields)
        case let .group(logicalOperator, children):
            children
                .map { $0.parenthesisedSummary(fields: fields) }
                .filter { !$0.isEmpty }
                .joined(separator: " \(logicalOperator.summary) ")
        case let .negation(child):
            "\(String(localized: .customFieldQueryNot)) (\(child.summary(fields: fields)))"
        }
    }

    private func parenthesisedSummary(fields: IdentifiedArrayOf<CustomField>) -> String {
        let summary = summary(fields: fields)
        guard case let .group(_, children) = self, children.count > 1 else {
            return summary
        }
        return "(\(summary))"
    }
}

private extension CustomFieldQueryLogicalOperator {
    var summary: String {
        switch self {
        case .and:
            String(localized: .customFieldQueryAnd)
        case .or:
            String(localized: .customFieldQueryOr)
        }
    }
}

private extension CustomFieldQuery.Atom {

    func summary(fields: IdentifiedArrayOf<CustomField>) -> String {
        let field = fields[id: field]
        let name = field?.name ?? "\(String(localized: .customFieldQueryUnknownField)) (\(self.field.rawValue))"

        if let phrase = booleanPhrase {
            return "\(name) \(phrase)"
        }
        return "\(name) \(op.summarySymbol) \(valueSummary(field: field))"
    }

    // `exists` and `isnull` carry a boolean that negates them, which reads as nonsense rendered as
    // an operator and a value — "Paid exists yes". They get whole phrases instead.
    private var booleanPhrase: String? {
        guard case let .bool(flag) = value else {
            return nil
        }
        switch op {
        case .exists:
            return String(localized: flag ? .customFieldQueryExists : .customFieldQueryDoesNotExist)
        case .isnull:
            return String(localized: flag ? .customFieldQueryIsEmpty : .customFieldQueryIsNotEmpty)
        default:
            return nil
        }
    }

    private func valueSummary(field: CustomField?) -> String {
        switch value {
        case let .array(elements):
            arraySummary(elements, field: field)
        default:
            text(for: value, field: field)
        }
    }

    // A documentlink array holds document ids, which say nothing to a reader. Resolving titles
    // here would mean the filter sheet could not render until they loaded, so it counts them.
    private func arraySummary(_ elements: [JSONValue], field: CustomField?) -> String {
        guard field?.dataType == .documentLink else {
            return elements.map { text(for: $0, field: field) }.joined(separator: ", ")
        }
        return String(localized: .numberOfDocuments(elements.count))
    }

    private func text(for value: JSONValue, field: CustomField?) -> String {
        switch value {
        case let .bool(flag):
            String(flag)
        case let .number(number):
            wholeNumberText(number)
        case let .string(text):
            label(for: text, field: field) ?? text
        default:
            ""
        }
    }

    // A monetary or integer value arrives as a Double, and "100.0" is not what anyone typed.
    private func wholeNumberText(_ number: Double) -> String {
        guard number.rounded() == number, let whole = Int(exactly: number.rounded()) else {
            return String(number)
        }
        return String(whole)
    }

    // A select field stores an opaque option id; the label is the only part worth showing.
    private func label(for optionId: String, field: CustomField?) -> String? {
        field?.extraData?.selectOptions?.first { $0.id == optionId }?.label
    }
}

private extension CustomFieldQueryOperator {
    var summarySymbol: String {
        switch self {
        case .exact:
            "="
        case .gt:
            ">"
        case .gte:
            "≥"
        case .lt:
            "<"
        case .lte:
            "≤"
        default:
            description.localizedLowercase
        }
    }
}
