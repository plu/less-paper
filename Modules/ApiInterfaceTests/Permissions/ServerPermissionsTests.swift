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

    @Test
    func canViewHistory_ownerWithViewLogEntry() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    @Test
    func canViewHistory_unownedDocument() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(permissions.canViewHistory(of: .testValue(owner: nil)))
    }

    // The endpoint answers 403 here even with view_logentry.
    @Test
    func canViewHistory_anotherUsersDocumentIsDenied() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(!permissions.canViewHistory(of: .testValue(owner: 6)))
    }

    @Test
    func canViewHistory_superuserSeesAnotherUsersDocument() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: true), permissions: [])

        #expect(permissions.canViewHistory(of: .testValue(owner: 6)))
    }

    @Test
    func canViewHistory_withoutViewLogEntryIsDenied() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewDocument])

        #expect(!permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    @Test
    func canViewHistory_auditLogDisabledDeniesEvenASuperuser() {
        let permissions = writeHistory(
            user: .testValue(id: 5, isSuperuser: true),
            permissions: [.viewLogEntry],
            auditLogEnabled: false
        )

        #expect(!permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    // Nothing read yet: offer the section and let the server refuse it, same as can().
    @Test
    func canViewHistory_nothingCachedAllows() {
        let server = Server.testValue()

        #expect(ServerPermissions(server: server).canViewHistory(of: .testValue(owner: 6)))
    }

    private func writeHistory(
        user: User,
        permissions: [Permission]?,
        auditLogEnabled: Bool? = true
    ) -> ServerPermissions {
        @Shared(.auditLogEnabled(Server.testValue()))
        var cachedAuditLogEnabled: Bool?

        $cachedAuditLogEnabled.withLock { $0 = auditLogEnabled }

        return write(user: user, permissions: permissions)
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
