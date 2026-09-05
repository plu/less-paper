import Foundation
import SwiftSharing

// What a screen asks about permissions. The two caches are held rather than read through a
// dependency so that a foreground refresh re-renders the screen: @Shared notifies observation, and a
// boolean computed once on appear would not.
//
// Every existing test uses the same fixed Server.testValue() id, so two ServerPermissions built in
// two different @Test functions resolve @Shared keys that are identical by value - and that is
// harmless. swift-dependencies caches a Shared's underlying reference under a key that includes the
// current Swift Testing Test.ID, so PersistentReferences (swift-sharing's weak-reference registry)
// and the in-memory file storage behind it are both resolved fresh per test rather than shared across
// the process. Two tests holding the "same" key by value are really reading two different registries
// backed by two different stores, so one test's seeded permissions can never leak into another's.
// This is the same per-Test.ID caching that let PermissionsQueryCache (removed with PermissionsQuery)
// keep one ServerPermissions alive per server without tests contaminating each other.
//
// That isolation holds only because every ServerPermissions here is constructed on the test's own
// task: a Shared built from a detached task does not inherit the test's task-locals and resolves
// under a process-global registry instead, which would silently render a seeded fixture as ungated.
public struct ServerPermissions: Equatable, Sendable {

    @Shared var permissions: [Permission]?

    @Shared var currentUser: User?

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
