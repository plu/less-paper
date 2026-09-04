import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

// The one question the rest of the app asks about permissions. A client rather than a free function
// so a feature test can grant or deny without writing to a cache.
@DependencyClient
public struct PermissionsQuery: Sendable {

    // Defaults to true for the same reason the live value falls back to true, but this is not a free
    // pass: @DependencyClient reports an unstubbed call as a failure (IssueReporting.reportIssue
    // "Unimplemented: ...") before returning the default, so a test that forgets to stub this fails
    // with a reported issue and also sees the app it has always seen. Once Projects 2 and 3 gate on
    // this, every feature test that reaches a gated view - and SnapshotBootstrap.swift - will need
    // to stub permissionsQuery explicitly.
    public var can: @Sendable (_ permission: Permission, _ server: Server) -> Bool = { _, _ in true }
}

// swift-sharing's registry holds a Shared's underlying reference weakly, so a Shared built and
// dropped inside `can` re-reads the file and re-arms two DispatchSources on every single call -
// fine while nothing calls `can`, not fine once a view body does it every frame while scrolling.
// Keeping one pair alive per server is what makes that cheap.
//
// This has to be a dependency, not a plain `static let`: a bare static dictionary keyed by
// Server.ID would survive between @Test cases, but every existing test uses the same fixed
// Server.testValue() id and each gets its own in-memory file storage, so the second test to run
// would be handed back the first test's Shared and silently read the first test's permissions.
// PersistentReferences, the registry this is caching a lookup into, sidesteps exactly that by
// making itself a dependency too (one instance for `liveValue`, a fresh one per test for
// `testValue`) - mirroring that here keeps our cache's lifetime matched to the registry's.
private final class PermissionsQueryCache: DependencyKey, @unchecked Sendable {

    static var liveValue: PermissionsQueryCache { PermissionsQueryCache() }

    static var testValue: PermissionsQueryCache { PermissionsQueryCache() }

    private let pairs = LockIsolated<[Server.ID: (permissions: Shared<[Permission]?>, user: Shared<User?>)]>([:])

    // Locked because `can` is @Sendable and may be called concurrently.
    func pair(for server: Server) -> (permissions: Shared<[Permission]?>, user: Shared<User?>) {
        pairs.withValue { pairs in
            if let pair = pairs[server.id] {
                return pair
            }
            @Shared(.permissions(server))
            var permissions: [Permission]?
            @Shared(.currentUser(server))
            var user: User?
            let pair = (permissions: $permissions, user: $user)
            pairs[server.id] = pair
            return pair
        }
    }
}

extension PermissionsQuery: DependencyKey {

    public static let liveValue = Self(
        can: { permission, server in
            @Dependency(PermissionsQueryCache.self)
            var cache

            let pair = cache.pair(for: server)

            // Nothing read yet, so nothing to gate on. Gating is presentation, not enforcement - the
            // server still refuses what it should. This branch is why the cache is optional rather
            // than an empty array: contains() on an empty array denies everything, which is the
            // opposite answer to the same question.
            guard let permissions = pair.permissions.wrappedValue else {
                return true
            }

            // Superuser first, matching the web UI. Django hands a superuser every permission
            // anyway, so this is belt and braces - and it stays true if that ever stops.
            return pair.user.wrappedValue?.isSuperuser == true || permissions.contains(permission)
        }
    )
}

extension PermissionsQuery: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var permissionsQuery: PermissionsQuery {
        get { self[PermissionsQuery.self] }
        set { self[PermissionsQuery.self] = newValue }
    }
}
