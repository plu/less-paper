import Foundation
import SwiftSharing

public struct DocumentSwipeActionSettings: Codable, Equatable, Sendable {

    // A third button is a menu the user has to stop and read, and a full swipe only ever fires the
    // first one anyway. The long-press menu is where the complete list already lives.
    public static let maximumActionsPerEdge = 2

    // One configuration for every document list. The lists show the same rows, and a swipe is worth
    // having only once you have stopped looking at it - which a binding that changes between screens
    // never lets you do.
    public var leading: [DocumentSwipeAction]
    public var trailing: [DocumentSwipeAction]

    private enum CodingKeys: String, CodingKey {
        case leading, trailing
    }

    public init(
        leading: [DocumentSwipeAction] = [.edit],
        trailing: [DocumentSwipeAction] = [.share]
    ) {
        self.leading = leading
        self.trailing = trailing
    }

    // Decoded through the raw strings rather than the enum, and every key optional: a synthesised
    // decoder throws on a case or a key it does not know, which would discard the whole preference
    // rather than the one part a newer build wrote.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        leading = try container.decodeIfPresent([String].self, forKey: .leading)?
            .compactMap(DocumentSwipeAction.init(rawValue:)) ?? defaults.leading
        trailing = try container.decodeIfPresent([String].self, forKey: .trailing)?
            .compactMap(DocumentSwipeAction.init(rawValue:)) ?? defaults.trailing
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
