import ApiInterface
import Dependencies
import Foundation

struct DocumentHistoryChangeLine: Equatable {

    let label: String

    let value: String
}

extension DocumentHistoryChangeLine {

    init(change: AuditLogEntry.Change, server: Server) {
        switch change {
        case let .customField(field, value):
            self.init(label: field, value: value)
        case let .field(key, _, new):
            self.init(label: key.titleCased, value: Self.value(for: key, new, server: server))
        case let .relation(key, operation, objects):
            self.init(label: "\(operation.titleCased) \(key.titleCased)", value: objects.joined(separator: ", "))
        }
    }

    private static let contentLimit = 100

    // Names are resolved on every render rather than stored: a correspondent renamed since reads
    // with its current name without refetching the history.
    private static func value(for key: String, _ value: JSONValue?, server: Server) -> String {
        guard let value else {
            return "—"
        }

        switch key {
        case "content":
            let text = value.auditLogText
            return text.count > contentLimit ? String(text.prefix(contentLimit)) + "…" : text
        case "correspondent":
            return resolve(value) { Correspondent.Id(rawValue: $0).get(server)?.name }
        case "document_type":
            return resolve(value) { DocumentType.Id(rawValue: $0).get(server)?.name }
        case "owner":
            return resolve(value) { User.Id(rawValue: $0).get(server)?.username }
        case "storage_path":
            return resolve(value) { StoragePath.Id(rawValue: $0).get(server)?.path }
        case "tags":
            @Dependency(\.apiCache)
            var apiCache
            return resolve(value) { apiCache.tag(Tag.Id(rawValue: $0), server)?.name }
        default:
            return value.auditLogText
        }
    }

    private static func resolve(_ value: JSONValue, name: (Int) -> String?) -> String {
        if case let .array(values) = value {
            return values.map { resolve($0, name: name) }.joined(separator: ", ")
        }
        guard let id = value.auditLogId else {
            return value.auditLogText
        }
        return name(id) ?? String(id)
    }
}

private extension JSONValue {

    // Ids arrive as strings ("8") from the scalar-change path and as numbers (97) from the others.
    var auditLogId: Int? {
        switch self {
        case let .number(value):
            Int(exactly: value)
        case let .string(value):
            Int(value)
        default:
            nil
        }
    }

    var auditLogText: String {
        switch self {
        case let .array(values):
            values.map(\.auditLogText).joined(separator: ", ")
        case let .bool(value):
            String(value)
        case .null:
            "—"
        case let .number(value):
            Int(exactly: value).map(String.init) ?? String(value)
        case .object:
            "…"
        case let .string(value):
            value
        }
    }
}

private extension String {

    // The web's titlecase pipe: first letter of each space-separated word up, the rest down.
    var titleCased: String {
        split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
