import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Logging

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

        @Dependency(\.getCustomFields.execute)
        var getCustomFields

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
        async let customFields = try await getCustomFields(server)
        async let documentTypes = try await getDocumentTypes(server)
        async let currentUser = try await getCurrentUser(server)
        async let groups = try await getGroups(server)
        async let savedViews = try await getSavedViews(server)
        async let statistics = try await getStatistics(server)
        async let storagePaths = try await getStoragePaths(server)
        async let tags = try await getTags(server)
        async let users = try await getUsers(server)

        _ = try await correspondents
        _ = try await customFields
        _ = try await documentTypes
        _ = try await currentUser
        _ = try await savedViews
        _ = try await statistics
        _ = try await storagePaths
        _ = try await tags

        // Users and groups are the owner and permission pickers, and nothing else. A paperless
        // account without view_user and view_group answers 403 for both while every other endpoint
        // above succeeds - and because adding a server runs this, that one permission gap used to
        // make the server unaddable (#51). Someone who cannot read the user list cannot meaningfully
        // assign an owner either, so an empty picker is the honest outcome, and it is a great deal
        // better than an app that cannot be reached at all.
        //
        // Not narrowed to 403: ApiError carries the body, not the status. Narrowing it would mean
        // widening ApiError, and there is little to buy - a server that is down or unreachable fails
        // the eight awaits above, so what reaches here is a failure specific to these two endpoints.
        @Dependency(\.log)
        var log

        do {
            _ = try await groups
        } catch {
            log.warning("groups unavailable, permission pickers will be empty: \(error.localizedDescription)", category: .api)
        }

        do {
            _ = try await users
        } catch {
            log.warning("users unavailable, owner and permission pickers will be empty: \(error.localizedDescription)", category: .api)
        }
    }
}
