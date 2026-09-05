@testable import ApiInterface

import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct ServerPermissionsTests {

    @Test
    func superuserCanDoAnythingWithoutHoldingThePermission() {
        let permissions = write(user: .testValue(isSuperuser: true), permissions: [])

        #expect(permissions.can(.deleteTag))
    }

    @Test
    func nonSuperuserHoldingThePermissionCan() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [.changeTag])

        #expect(permissions.can(.changeTag))
    }

    @Test
    func nonSuperuserLackingThePermissionCannot() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [.viewTag])

        #expect(!permissions.can(.changeTag))
    }

    // Nothing read yet, so nothing known. Gating is presentation, not enforcement: show the control
    // and let the server refuse it. Deleting this branch hides the whole app from anyone whose
    // paperless does not send the key.
    @Test
    func nilCacheAllowsEverything() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: nil)

        #expect(permissions.can(.deleteTag))
    }

    // One character apart from the case above and the opposite answer: the server was read and it
    // granted nothing.
    @Test
    func emptyCacheAllowsNothing() {
        let permissions = write(user: .testValue(isSuperuser: false), permissions: [])

        #expect(!permissions.can(.deleteTag))
    }

    private func write(user: User, permissions: [Permission]?) -> ServerPermissions {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var cachedUser: User?

        @Shared(.permissions(server))
        var cachedPermissions: [Permission]?

        $cachedUser.withLock { $0 = user }
        $cachedPermissions.withLock { $0 = permissions }

        return ServerPermissions(server: server)
    }
}
