import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Logging
import SwiftSharing

extension UpdateCacheUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension UpdateCacheUseCase {
    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.authenticationProvider)
        var authenticationProvider

        @Dependency(\.log)
        var log

        // Concrete, not @Dependency(\.continuousClock): typed as `any Clock<Duration>`, calling
        // .duration(to:) on its existential .now fights the type checker. Nothing asserts on the
        // elapsed value, so injectability buys nothing here.
        let clock = ContinuousClock()

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        // Derived, not stored: a token means token auth, and its absence means remote-user mode,
        // where a forward-auth proxy authenticates and no token exists. This does not distinguish a
        // token obtained through OIDC from one obtained with a password - nothing records that.
        let token = try? await authenticationProvider.getToken(server: server)

        // "connecting", not "connected": nothing has been asked of the server yet. The line stays
        // ahead of the requests because the API version and the auth mode are exactly what a
        // support reader wants when the connection is the thing that failed - and "cache updated"
        // below is what marks success, so a connecting line with nothing after it reads correctly.
        log.info(
            [
                "connecting",
                "API version \(apiVersion.map(String.init) ?? "unknown")",
                "auth: \(token == nil ? "remote-user" : "token")",
            ]
            .joined(separator: " · "),
            category: .server
        )

        let started = clock.now

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

        let correspondentsCount = try await correspondents.count
        let customFieldsCount = try await customFields.count
        let documentTypesCount = try await documentTypes.count
        _ = try await currentUser
        let savedViewsCount = try await savedViews.count
        _ = try await statistics
        let storagePathsCount = try await storagePaths.count
        let tagsCount = try await tags.count

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

        log.info(
            [
                "cache updated in \(Self.formatted(started.duration(to: clock.now)))",
                Self.pluralised(tagsCount, "tag"),
                Self.pluralised(correspondentsCount, "correspondent"),
                Self.pluralised(documentTypesCount, "document type"),
                Self.pluralised(savedViewsCount, "saved view"),
                Self.pluralised(storagePathsCount, "storage path"),
                Self.pluralised(customFieldsCount, "custom field"),
            ]
            .joined(separator: " · "),
            category: .server
        )
    }

    // en_US_POSIX for the same reason StorageUsage.formattedBytes() pins it: the file is read by
    // whoever the user sends it to, and "1,8 Sek." on their side of a support thread is noise. The
    // narrow width is what makes it "1.8s" rather than "1.8 sec".
    static func formatted(_ duration: Duration) -> String {
        duration.formatted(
            .units(allowed: [.seconds], width: .narrow, fractionalPart: .show(length: 1))
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    static func pluralised(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
