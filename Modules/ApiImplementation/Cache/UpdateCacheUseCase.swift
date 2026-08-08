import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension UpdateCacheUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension UpdateCacheUseCase {
    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getCorrespondents.execute)
        var getCorrespondents

        @Dependency(\.getCurrentUser.execute)
        var getCurrentUser

        @Dependency(\.getDocumentTypes.execute)
        var getDocumentTypes

        @Dependency(\.getGroups.execute)
        var getGroups

        @Dependency(\.getSavedViews.execute)
        var getSavedViews

        @Dependency(\.getStatistics.execute)
        var getStatistics

        @Dependency(\.getStoragePaths.execute)
        var getStoragePaths

        @Dependency(\.getTags.execute)
        var getTags

        @Dependency(\.getUsers.execute)
        var getUsers

        async let correspondents = try await getCorrespondents(server)
        async let documentTypes = try await getDocumentTypes(server)
        async let currentUser = try await getCurrentUser(server)
        async let groups = try await getGroups(server)
        async let savedViews = try await getSavedViews(server)
        async let statistics = try await getStatistics(server)
        async let storagePaths = try await getStoragePaths(server)
        async let tags = try await getTags(server)
        async let users = try await getUsers(server)

        _ = try await correspondents
        _ = try await documentTypes
        _ = try await currentUser
        _ = try await groups
        _ = try await savedViews
        _ = try await statistics
        _ = try await storagePaths
        _ = try await tags
        _ = try await users
    }
}
