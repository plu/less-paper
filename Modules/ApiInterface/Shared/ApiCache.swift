import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

@DependencyClient
public struct ApiCache: Sendable {

    public var correspondent: @Sendable (
        _ id: Correspondent.Id?,
        _ server: Server
    ) -> Correspondent?

    public var documentType: @Sendable (
        _ id: DocumentType.Id?,
        _ server: Server
    ) -> DocumentType?

    public var group: @Sendable (
        _ id: Group.Id?,
        _ server: Server
    ) -> Group?

    public var storagePath: @Sendable (
        _ id: StoragePath.Id?,
        _ server: Server
    ) -> StoragePath?

    public var tag: @Sendable (
        _ id: Tag.Id?,
        _ server: Server
    ) -> Tag?

    public var user: @Sendable (
        _ id: User.Id?,
        _ server: Server
    ) -> User?
}

extension ApiCache: DependencyKey, TestDependencyKey {
    public static let liveValue = Self(
        correspondent: correspondent(id:server:),
        documentType: documentType(id:server:),
        group: group(id:server:),
        storagePath: storagePath(id:server:),
        tag: tag(id:server:),
        user: user(id:server:)
    )

    public static let previewValue = Self(
        correspondent: { _, _ in .testValue() },
        documentType: { _, _ in .testValue() },
        group: group(id:server:),
        storagePath: { _, _ in .testValue() },
        tag: { id, _ in
            switch id {
            case 1: .testValue(color: "#a6cee3", id: 1, name: "One", textColor: "000000")
            case 2: .testValue(color: "#1f78b4", id: 2, name: "Two", textColor: "ffffff")
            case 3: .testValue(color: "#b2df8a", id: 3, name: "Three", textColor: "000000")
            case 4: .testValue(color: "#33a02c", id: 4, name: "Four", textColor: "ffffff")
            case 5: .testValue(color: "#fb9a99", id: 5, name: "Five", textColor: "000000")
            case 6: .testValue(color: "#e31a1c", id: 6, name: "Six", textColor: "ffffff")
            case 7: .testValue(color: "#fdbf6f", id: 7, name: "Seven", textColor: "000000")
            default: .testValue()
            }
        },
        user: { _, _ in .testValue() }
    )

    public static let testValue = previewValue
}

extension ApiCache {
    static func correspondent(
        id: Correspondent.Id?,
        server: Server
    ) -> Correspondent? {
        guard let id else {
            return nil
        }

        if let cache = correspondents[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.correspondents(server))

        correspondents.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    static func documentType(
        id: DocumentType.Id?,
        server: Server
    ) -> DocumentType? {
        guard let id else {
            return nil
        }

        if let cache = documentTypes[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.documentTypes(server))

        documentTypes.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    static func group(
        id: Group.Id?,
        server: Server
    ) -> Group? {
        guard let id else {
            return nil
        }

        if let cache = groups[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.groups(server))

        groups.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    static func storagePath(
        id: StoragePath.Id?,
        server: Server
    ) -> StoragePath? {
        guard let id else {
            return nil
        }

        if let cache = storagePaths[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.storagePaths(server))

        storagePaths.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    static func tag(
        id: Tag.Id?,
        server: Server
    ) -> Tag? {
        guard let id else {
            return nil
        }

        if let cache = tags[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.tags(server))

        tags.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    static func user(
        id: User.Id?,
        server: Server
    ) -> User? {
        guard let id else {
            return nil
        }

        if let cache = users[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.users(server))

        users.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }

    private static let correspondents: LockIsolated<[Server: Shared<IdentifiedArrayOf<Correspondent>>]> = .init([:])
    private static let documentTypes: LockIsolated<[Server: Shared<IdentifiedArrayOf<DocumentType>>]> = .init([:])
    private static let groups: LockIsolated<[Server: Shared<IdentifiedArrayOf<Group>>]> = .init([:])
    private static let storagePaths: LockIsolated<[Server: Shared<IdentifiedArrayOf<StoragePath>>]> = .init([:])
    private static let tags: LockIsolated<[Server: Shared<IdentifiedArrayOf<Tag>>]> = .init([:])
    private static let users: LockIsolated<[Server: Shared<IdentifiedArrayOf<User>>]> = .init([:])
}

public extension DependencyValues {
    var apiCache: ApiCache {
        get { self[ApiCache.self] }
        set { self[ApiCache.self] = newValue }
    }
}
