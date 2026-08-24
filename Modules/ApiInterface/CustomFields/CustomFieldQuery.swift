import Foundation

public indirect enum CustomFieldQuery: Equatable, Sendable {
    case atom(Atom)
    case group(CustomFieldQueryLogicalOperator, [CustomFieldQuery])
    case negation(CustomFieldQuery)

    public struct Atom: Equatable, Sendable {
        public var field: CustomField.Id
        public var op: CustomFieldQueryOperator
        public var value: JSONValue

        public init(field: CustomField.Id, op: CustomFieldQueryOperator, value: JSONValue) {
            self.field = field
            self.op = op
            self.value = value
        }
    }
}

extension CustomFieldQuery: Codable {

    private static let negationToken = "NOT"

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        // The first element tells the two shapes apart: a string is a logical operator, anything
        // else is a field id and this is an atom.
        guard let token = try? container.decode(String.self) else {
            var atomContainer = try decoder.unkeyedContainer()
            self = try .atom(.init(
                field: atomContainer.decode(CustomField.Id.self),
                op: atomContainer.decode(CustomFieldQueryOperator.self),
                value: atomContainer.decode(JSONValue.self)
            ))
            return
        }

        if token == Self.negationToken {
            self = try .negation(container.decode(NegatedChild.self).query)
            return
        }

        guard let logicalOperator = CustomFieldQueryLogicalOperator(rawValue: token) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid logical operator '\(token)'"
            )
        }
        self = try .group(logicalOperator, container.decode([Self].self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .atom(atom):
            try container.encode(atom.field)
            try container.encode(atom.op)
            try container.encode(atom.value)
        case let .group(logicalOperator, children):
            try container.encode(logicalOperator)
            try container.encode(children)
        case let .negation(child):
            try container.encode(Self.negationToken)
            try container.encode(child)
        }
    }
}

// `NOT` carries its child inline, but a query written by another client may wrap it in a
// single-element list — the shape the server itself rejects. Decoding that here costs nothing and
// keeps such a saved view openable. Branching lives in its own type so a failed first attempt
// happens on this value's decoder rather than half-consuming the parent's container.
private struct NegatedChild: Decodable {
    let query: CustomFieldQuery

    init(from decoder: Decoder) throws {
        if let query = try? CustomFieldQuery(from: decoder) {
            self.query = query
            return
        }
        let wrapped = try [CustomFieldQuery](from: decoder)
        guard wrapped.count == 1 else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.unkeyedContainer(),
                debugDescription: "A negation takes exactly one child"
            )
        }
        query = wrapped[0]
    }
}

public extension CustomFieldQuery {

    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let query = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = query
    }

    var json: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
