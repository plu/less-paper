@testable import ApiInterface

import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct PermissionsQueryTests {

    @Test
    func superuserCanDoAnythingWithoutHoldingThePermission() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: true), permissions: [], server: server)

        #expect(PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    @Test
    func nonSuperuserHoldingThePermissionCan() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [.changeDocument], server: server)

        #expect(PermissionsQuery.liveValue.can(.changeDocument, server))
    }

    @Test
    func nonSuperuserLackingThePermissionCannot() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [.viewDocument], server: server)

        #expect(!PermissionsQuery.liveValue.can(.changeDocument, server))
    }

    // Nothing has been read, so nothing is known. Gating is presentation, not enforcement: show the
    // control and let the server refuse it. Deleting this branch hides the whole app from anyone
    // whose paperless does not send the key.
    @Test
    func nilCacheAllowsEverything() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: nil, server: server)

        #expect(PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    // One character apart from the case above and the opposite answer: the server was read and it
    // granted nothing.
    @Test
    func emptyCacheAllowsNothing() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [], server: server)

        #expect(!PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    private func write(user: User, permissions: [Permission]?, server: Server) {
        @Shared(.currentUser(server))
        var cachedUser: User?

        @Shared(.permissions(server))
        var cachedPermissions: [Permission]?

        $cachedUser.withLock { $0 = user }
        $cachedPermissions.withLock { $0 = permissions }
    }
}
