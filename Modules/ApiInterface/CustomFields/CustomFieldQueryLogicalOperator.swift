import Foundation

// `NOT` is deliberately absent. The server takes it with a single child passed inline —
// `["NOT",[7,"exists",true]]` — where `AND` and `OR` take a list, and `["NOT",[a,b]]` is a 500
// rather than a 400. `CustomFieldQuery.negation` models it as its own arity-1 case so that shape
// cannot be built.
public enum CustomFieldQueryLogicalOperator: String, CaseIterable, Codable, Hashable, Sendable {
    case and = "AND"
    case or = "OR"
}

extension CustomFieldQueryLogicalOperator: Identifiable {
    public var id: String {
        rawValue
    }
}
