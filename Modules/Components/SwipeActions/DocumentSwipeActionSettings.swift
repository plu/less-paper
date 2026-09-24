import Foundation
import SwiftSharing

public struct DocumentSwipeActionSettings: Codable, Equatable, Sendable {

    public struct Edges: Equatable, Sendable {
        public var leading: [DocumentSwipeAction]
        public var trailing: [DocumentSwipeAction]

        public init(
            leading: [DocumentSwipeAction],
            trailing: [DocumentSwipeAction]
        ) {
            self.leading = leading
            self.trailing = trailing
        }
    }

    // A third button is a menu the user has to stop and read, and a full swipe only ever fires the
    // first one anyway. The long-press menu is where the complete list already lives.
    public static let maximumActionsPerEdge = 2

    public var documents: Edges
    public var inbox: Edges

    public init(
        documents: Edges = .init(leading: [.edit], trailing: [.clearInboxTags]),
        inbox: Edges = .init(leading: [.edit], trailing: [.clearInboxTags])
    ) {
        self.documents = documents
        self.inbox = inbox
    }
}

extension DocumentSwipeActionSettings.Edges: Codable {

    private enum CodingKeys: String, CodingKey {
        case leading, trailing
    }

    // Decoded through the raw strings rather than the enum: a synthesised decoder throws on a case
    // it does not know, which would discard the whole preference rather than the one action a newer
    // build named.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leading = try container.decode([String].self, forKey: .leading)
            .compactMap(DocumentSwipeAction.init(rawValue:))
        trailing = try container.decode([String].self, forKey: .trailing)
            .compactMap(DocumentSwipeAction.init(rawValue:))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leading.map(\.rawValue), forKey: .leading)
        try container.encode(trailing.map(\.rawValue), forKey: .trailing)
    }
}

public extension SharedReaderKey
    where Self == FileStorageKey<DocumentSwipeActionSettings>.Default {

    // Not keyed by server, unlike the caches in ApiInterface: this is a preference, and a user's
    // muscle memory does not change when they switch servers. Same shape as the review and tip
    // prompts, which are also app-wide.
    static var documentSwipeActions: Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "document-swipe-actions.json"),
                decoder: JSONDecoder(),
                encoder: JSONEncoder()
            ),
            default: .init()
        ]
    }
}

// Components cannot see ApiInterface, which has its own copy. CertificatesFeature carries a third
// for the same reason.
private extension URL {

    static var applicationGroupDirectory: URL {
        guard let applicationGroupDirectory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.plunien.app.Paperless")
        else {
            return .documentsDirectory
        }
        return applicationGroupDirectory
    }
}
