import Foundation

public extension CustomFieldQuery {

    // Both limits mirror the paperless-ngx web client. The server enforces neither — it accepted
    // depth 6 and six atoms when tested — so they are a product choice about what fits on a phone,
    // and about keeping a query portable between the two clients.
    static let maximumAtoms = 5

    static let maximumDepth = 4

    var atomCount: Int {
        switch self {
        case .atom:
            1
        case let .group(_, children):
            children.reduce(0) { $0 + $1.atomCount }
        case let .negation(child):
            child.atomCount
        }
    }

    var depth: Int {
        switch self {
        case .atom:
            1
        case let .group(_, children):
            1 + (children.map(\.depth).max() ?? 0)
        case let .negation(child):
            1 + child.depth
        }
    }

    // Drops atoms the user has not finished filling in, then any group or negation left with
    // nothing inside. An incomplete atom would otherwise be sent while the sheet is still open —
    // the live match count updates on every keystroke — and the server answers a half-built
    // condition with a 400.
    var pruned: Self? {
        switch self {
        case let .atom(atom):
            atom.isComplete ? self : nil
        case let .group(logicalOperator, children):
            {
                let pruned = children.compactMap(\.pruned)
                return pruned.isEmpty ? nil : .group(logicalOperator, pruned)
            }()
        case let .negation(child):
            child.pruned.map { .negation($0) }
        }
    }
}

public extension CustomFieldQueryValueKind {
    var defaultValue: JSONValue {
        switch self {
        case .array:
            .array([])
        case .boolean:
            .bool(true)
        case .number:
            .number(0)
        case .string:
            .string("")
        }
    }
}

public extension CustomFieldQuery.Atom {

    var isComplete: Bool {
        switch (op.valueKind, value) {
        case let (.array, .array(elements)):
            !elements.isEmpty
        case (.boolean, .bool):
            true
        case (.number, .number):
            true
        case let (.string, .string(text)):
            !text.isEmpty
        // A value whose kind does not match its operator is a field or operator change the editor
        // has not finished applying, not a condition the user meant to send.
        default:
            false
        }
    }
}

public extension CustomFieldQuery.Atom {

    // A new condition starts on the first operator its field admits. A field whose data type the
    // client does not know — `unknown` is the decoding fallback — admits none, so it cannot seed a
    // condition at all.
    init?(defaultFor field: CustomField) {
        guard let queryOperator = CustomFieldQueryOperator.operators(for: field.dataType).first else {
            return nil
        }
        self.init(
            field: field.id,
            op: queryOperator,
            value: Self.defaultValue(for: queryOperator, field: field)
        )
    }

    // Changing the field can invalidate the operator, and changing the operator can invalidate the
    // value. Both resets happen here so no editor can leave an atom the server would 400 on.
    mutating func setField(_ field: CustomField) {
        self.field = field.id
        let operators = CustomFieldQueryOperator.operators(for: field.dataType)
        guard !operators.contains(op) else {
            // The operator survives, so the value does too — except across select fields, where it
            // is an option id that means nothing to the new field. Free text carries over fine.
            if case let .string(text) = value,
               let options = field.extraData?.selectOptions,
               !options.contains(where: { $0.id == text }) {
                value = Self.defaultValue(for: op, field: field)
            }
            return
        }
        setOperator(operators.first ?? op, field: field)
    }

    mutating func setOperator(_ queryOperator: CustomFieldQueryOperator, field: CustomField?) {
        guard op.valueKind != queryOperator.valueKind else {
            op = queryOperator
            return
        }
        op = queryOperator
        value = Self.defaultValue(for: queryOperator, field: field)
    }

    // A select field stores an opaque option id, so an empty string is not a value the field can
    // ever hold: it renders as a blank picker with no matching tag. Seeding the first option keeps
    // the control showing something real and the condition complete.
    private static func defaultValue(for queryOperator: CustomFieldQueryOperator, field: CustomField?) -> JSONValue {
        guard queryOperator.valueKind == .string,
              let firstOption = field?.extraData?.selectOptions?.first?.id
        else {
            return queryOperator.valueKind.defaultValue
        }
        return .string(firstOption)
    }
}
