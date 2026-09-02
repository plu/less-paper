import ApiInterface
import Dependencies
import Testing

@testable import ApiImplementation

@Suite
struct UpdateCacheUseCaseTests {

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
}
