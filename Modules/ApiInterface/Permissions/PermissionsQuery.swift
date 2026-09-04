import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

// The one question the rest of the app asks about permissions. A client rather than a free function
// so a feature test can grant or deny without writing to a cache.
@DependencyClient
public struct PermissionsQuery: Sendable {

    // Defaults to true for the same reason the live value falls back to true: a test that forgets to
    // stub this sees the app it has always seen, not an empty one.
    public var can: @Sendable (_ permission: Permission, _ server: Server) -> Bool = { _, _ in true }
}

extension PermissionsQuery: DependencyKey {

    public static let liveValue = Self(
        can: { permission, server in
            @Shared(.permissions(server))
            var permissions: [Permission]?

            // Nothing read yet, so nothing to gate on. Gating is presentation, not enforcement - the
            // server still refuses what it should. This branch is why the cache is optional rather
            // than an empty array: contains() on an empty array denies everything, which is the
            // opposite answer to the same question.
            guard let permissions else {
                return true
            }

            @Shared(.currentUser(server))
            var user: User?

            // Superuser first, matching the web UI. Django hands a superuser every permission
            // anyway, so this is belt and braces - and it stays true if that ever stops.
            return user?.isSuperuser == true || permissions.contains(permission)
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
