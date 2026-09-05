import Foundation
import SwiftSharing

// What a screen asks about permissions. The two caches are held rather than read through a
// dependency so that a foreground refresh re-renders the screen: @Shared notifies observation, and a
// boolean computed once on appear would not.
public struct ServerPermissions: Equatable, Sendable {

    @Shared public var permissions: [Permission]?

    @Shared public var currentUser: User?

    public init(server: Server) {
        _permissions = Shared(wrappedValue: nil, .permissions(server))
        _currentUser = Shared(wrappedValue: nil, .currentUser(server))
    }

    public func can(_ permission: Permission) -> Bool {
        // Nothing read yet, so nothing to gate on. This branch is why the cache is optional rather
        // than an empty array: contains() on an empty array denies everything, which is the opposite
        // answer to the same question.
        guard let permissions else {
            return true
        }

        // Superuser first, matching the web UI. Django hands a superuser every permission anyway, so
        // this is belt and braces - and it stays true if that ever stops.
        return currentUser?.isSuperuser == true || permissions.contains(permission)
    }
}
