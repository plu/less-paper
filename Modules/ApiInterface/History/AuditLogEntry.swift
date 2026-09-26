import Foundation
import Tagged

public struct AuditLogEntry: Equatable, Identifiable, Sendable {

    public typealias Id = Tagged<AuditLogEntry, Int>

    public let action: Action

    public let actor: Actor?

    public let changes: [Change]

    public let id: Id

    public let timestamp: Date

    public init(
        action: Action,
        actor: Actor?,
        changes: [Change],
        id: Id,
        timestamp: Date
    ) {
        self.action = action
        self.actor = actor
        self.changes = changes
        self.id = id
        self.timestamp = timestamp
    }
}

public extension AuditLogEntry {

    enum Action: Equatable, Sendable {
        case create
        case delete
        case other(String)
        case update
    }

    // The payload's actor carries two fields where User carries thirteen, so it cannot be decoded
    // as one — the same reason Note has its own Author.
    struct Actor: Decodable, Equatable, Sendable {

        public let id: User.Id

        public let username: String

        public init(
            id: User.Id,
            username: String
        ) {
            self.id = id
            self.username = username
        }
    }

    enum Change: Equatable, Sendable {
        case customField(field: String, value: String)
        case field(key: String, old: JSONValue?, new: JSONValue?)
        case relation(key: String, operation: String, objects: [String])
    }
}

extension AuditLogEntry: Decodable {

    private enum CodingKeys: String, CodingKey {
        case action, actor, changes, id, timestamp
    }

    // Sorted by key, as the web's keyvalue pipe sorts them, so both list a change in the same
    // place. A shape nothing here recognises costs its own line, not the entry: the audit log is
    // written by many server paths and one of them may grow a new shape.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(Action.self, forKey: .action)
        actor = try container.decodeIfPresent(Actor.self, forKey: .actor)
        id = try container.decode(Id.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        changes = try (container.decodeIfPresent([String: JSONValue].self, forKey: .changes) ?? [:])
            .sorted { $0.key < $1.key }
            .compactMap { Change(key: $0.key, value: $0.value) }
    }
}

extension AuditLogEntry.Action: Decodable {

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "create": self = .create
        case "delete": self = .delete
        case "update": self = .update
        default: self = .other(value)
        }
    }
}

private extension AuditLogEntry.Change {

    init?(key: String, value: JSONValue) {
        switch value {
        case let .array(pair) where pair.count == 2:
            self = .field(key: key, old: pair[0].auditLogValue, new: pair[1].auditLogValue)
        case let .object(object):
            switch object["type"]?.stringValue {
            case "m2m":
                guard let operation = object["operation"]?.stringValue,
                      let objects = object["objects"]?.arrayValue
                else {
                    return nil
                }
                self = .relation(key: key, operation: operation, objects: objects.compactMap(\.stringValue))
            case "custom_field":
                guard let field = object["field"]?.stringValue,
                      let value = object["value"]?.stringValue
                else {
                    return nil
                }
                self = .customField(field: field, value: value)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

private extension JSONValue {

    // django-auditlog writes an empty side as the string "None", and some paths as null.
    var auditLogValue: JSONValue? {
        switch self {
        case .null, .string("None"):
            nil
        default:
            self
        }
    }
}

public extension AuditLogEntry {

    static func testValue(
        action: Action = .update,
        actor: Actor? = .testValue(),
        changes: [Change] = [.relation(key: "tags", operation: "add", objects: ["Privat"])],
        id: Id = 1,
        timestamp: Date = .testValue()
    ) -> Self {
        .init(
            action: action,
            actor: actor,
            changes: changes,
            id: id,
            timestamp: timestamp
        )
    }
}

public extension AuditLogEntry.Actor {

    static func testValue(
        id: User.Id = 1,
        username: String = "admin"
    ) -> Self {
        .init(
            id: id,
            username: username
        )
    }
}
