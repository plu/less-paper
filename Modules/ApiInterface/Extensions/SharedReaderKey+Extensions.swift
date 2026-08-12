import Foundation
import IdentifiedCollections
import SwiftSharing
import Tagged

public extension SharedReaderKey where Self == FileStorageKey<User?> {

    static func currentUser(_ server: Server) -> Self {
        .fileStorage(
            .applicationGroupDirectory.appending(component: "\(server.id)-current-user.json"),
            decoder: .apiDecoder,
            encoder: .apiEncoder
        )
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Correspondent>>.Default {

    static func correspondents(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-correspondents.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<DocumentType>>.Default {

    static func documentTypes(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-document-types.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == InMemoryKey<IdentifiedArrayOf<Document>>.Default {

    /// Per-server store of document content, keyed by id.
    ///
    /// Used as an `id → Document` map — its ordering is meaningless and nothing displays it.
    /// In-memory rather than file-backed: documents are paginated and far more numerous than
    /// the other cached entities, and there is no offline requirement.
    static func documents(_ server: Server) -> Self {
        Self[
            .inMemory("\(server.id)-documents"),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Group>>.Default {

    static func groups(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-groups.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<StoragePath>>.Default {

    static func storagePaths(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-storage-paths.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<SavedView>>.Default {

    static func savedViews(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-saved-views.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Server>>.Default {

    static var servers: Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "servers.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<Server?> {

    static var selectedServer: Self {
        .fileStorage(
            .applicationGroupDirectory.appending(component: "default-server.json"),
            decoder: .apiDecoder,
            encoder: .apiEncoder
        )
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Tag>>.Default {

    static func tags(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-tags.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<User>>.Default {

    static func users(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-users.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}

public extension SharedReaderKey where Self == AppStorageKey<Int>.Default {

    static func inboxDocumentCount(_ server: Server) -> Self {
        Self[
            .appStorage("\(server.id)-inbox-document-count"),
            default: 0
        ]
    }
}

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
