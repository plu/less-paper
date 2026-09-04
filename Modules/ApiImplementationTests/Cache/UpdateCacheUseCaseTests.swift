import ApiInterface
import Dependencies
import Testing

@testable import ApiImplementation

@Suite
struct UpdateCacheUseCaseTests {

    // UpdateCacheUseCase awaits every one of these, so a test that omits one fails on an
    // unimplemented dependency rather than on what it meant to assert.
    private static func cachingStubs(
        count: Int = 1
    ) -> (inout DependencyValues) -> Void {
        { values in
            values.getCorrespondents.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getCurrentUser.execute = { _ in .testValue() }
            values.getDocumentTypes.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getGroups.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getSavedViews.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getStoragePaths.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getTags.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getUsers.execute = { _ in Array(repeating: .testValue(), count: count) }
        }
    }

    @Test
    func executeCallsAllCachingOperationsWithCorrectServer() async throws {
        let server = Server.testValue()
        let getCorrespondentsCalled = LockIsolated(false)
        let getCurrentUserCalled = LockIsolated(false)
        let getDocumentTypesCalled = LockIsolated(false)
        let getGroupsCalled = LockIsolated(false)
        let getSavedViewsCalled = LockIsolated(false)
        let getStoragePathsCalled = LockIsolated(false)
        let getTagsCalled = LockIsolated(false)
        let getUsersCalled = LockIsolated(false)

        try await withDependencies {
            $0.getCorrespondents.execute = { receivedServer in
                getCorrespondentsCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getCurrentUser.execute = { receivedServer in
                getCurrentUserCalled.setValue(true)
                #expect(receivedServer == server)
                return .testValue()
            }
            $0.getDocumentTypes.execute = { receivedServer in
                getDocumentTypesCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getGroups.execute = { receivedServer in
                getGroupsCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getSavedViews.execute = { receivedServer in
                getSavedViewsCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getStoragePaths.execute = { receivedServer in
                getStoragePathsCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getTags.execute = { receivedServer in
                getTagsCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
            $0.getUsers.execute = { receivedServer in
                getUsersCalled.setValue(true)
                #expect(receivedServer == server)
                return [.testValue()]
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(server)
        }

        #expect(getCorrespondentsCalled.value == true)
        #expect(getCurrentUserCalled.value == true)
        #expect(getDocumentTypesCalled.value == true)
        #expect(getGroupsCalled.value == true)
        #expect(getSavedViewsCalled.value == true)
        #expect(getStoragePathsCalled.value == true)
        #expect(getTagsCalled.value == true)
        #expect(getUsersCalled.value == true)
    }

    // A paperless account without view_user and view_group answers 403 on /api/users/ and
    // /api/groups/ while everything else succeeds, and adding the server ran this use case - so one
    // permission gap made the server unaddable. Reproduced against a live 3.0.5 instance.
    @Test
    func executeSurvivesUsersAndGroupsBeingForbidden() async throws {
        let server = Server.testValue()
        let forbidden = ApiError(errors: ["You do not have permission to perform this action."])
        let getTagsCalled = LockIsolated(false)

        try await withDependencies {
            $0.getCorrespondents.execute = { _ in [.testValue()] }
            $0.getCurrentUser.execute = { _ in .testValue() }
            $0.getDocumentTypes.execute = { _ in [.testValue()] }
            $0.getGroups.execute = { _ in throw forbidden }
            $0.getSavedViews.execute = { _ in [.testValue()] }
            $0.getStoragePaths.execute = { _ in [.testValue()] }
            $0.getTags.execute = { _ in
                getTagsCalled.setValue(true)
                return [.testValue()]
            }
            $0.getUsers.execute = { _ in throw forbidden }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(server)
        }

        #expect(getTagsCalled.value == true)
    }

    @Test
    func test_execute_logsTheConnectionShape() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs()(&$0)
            $0.authenticationProvider.getToken = { _ in "a-token" }
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        #expect(messages.value.contains { $0.hasPrefix("connecting · API version ") })
        #expect(messages.value.contains { $0.hasSuffix(" · auth: token") })
    }

    // Remote-user mode has no token: a forward-auth proxy authenticates and paperless takes the
    // injected identity. The line has to say so rather than fail.
    @Test
    func test_execute_reportsRemoteUserWhenThereIsNoToken() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs()(&$0)
            $0.authenticationProvider.getToken = { _ in nil }
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        #expect(messages.value.contains { $0.hasSuffix(" · auth: remote-user") })
    }

    @Test
    func test_execute_logsWhatItCached() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs(count: 1)(&$0)
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        let summary = try #require(messages.value.first { $0.hasPrefix("cache updated in ") })

        #expect(summary.contains("1 tag"))
        #expect(summary.contains("1 correspondent"))
        #expect(summary.contains("1 saved view"))

        // The duration is pinned to en_US_POSIX, so it is "0.0s" and never "0,0 Sek." - the file is
        // read by whoever the user sends it to, not by the device that wrote it.
        #expect(summary.contains(#/^cache updated in [0-9]+\.[0-9]s · /#))
    }
}
