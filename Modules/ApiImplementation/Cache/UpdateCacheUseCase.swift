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

        // Every list here can 403 on its own, and none of them is worth an app for. A paperless
        // account without view_tag answers 403 for tags while everything else succeeds - and
        // because adding a server runs this, a throw aborts the login after the token has already
        // been written to the keychain, leaving the account unreachable over a permission it only
        // needed in order to fill a cache. #51 was this bug for view_user and view_group; it is
        // the same bug for every one of these lists.
        //
        // Not narrowed to 403: ApiError carries the body, not the status, and narrowing it would
        // mean widening ApiError. What still fails a server that is down, unreachable or refusing
        // the credentials is the token request and the API version negotiation, which run before
        // this and still throw - so tolerance here cannot make a broken server look reachable.
        // Spelled out one block at a time rather than factored into a helper: an `async let`
        // cannot be captured by a closure at all - "Capturing 'async let' variables is not
        // supported" - so every attempt to pass these to a shared function fails to compile.
        var correspondentsCount: Int?
        do {
            correspondentsCount = try await correspondents.count
        } catch {
            log.warning("correspondents unavailable: \(error.localizedDescription)", category: .api)
        }

        var customFieldsCount: Int?
        do {
            customFieldsCount = try await customFields.count
        } catch {
            log.warning("custom fields unavailable: \(error.localizedDescription)", category: .api)
        }

        var documentTypesCount: Int?
        do {
            documentTypesCount = try await documentTypes.count
        } catch {
            log.warning("document types unavailable: \(error.localizedDescription)", category: .api)
        }

        var savedViewsCount: Int?
        do {
            savedViewsCount = try await savedViews.count
        } catch {
            log.warning("saved views unavailable: \(error.localizedDescription)", category: .api)
        }

        var storagePathsCount: Int?
        do {
            storagePathsCount = try await storagePaths.count
        } catch {
            log.warning("storage paths unavailable: \(error.localizedDescription)", category: .api)
        }

        var tagsCount: Int?
        do {
            tagsCount = try await tags.count
        } catch {
            log.warning("tags unavailable: \(error.localizedDescription)", category: .api)
        }

        do {
            _ = try await statistics
        } catch {
            log.warning("statistics unavailable: \(error.localizedDescription)", category: .api)
        }

        // Losing these costs gating and the owner pickers, both presentation. Someone who cannot
        // read the user list cannot meaningfully assign an owner either, so an empty picker is the
        // honest outcome.
        do {
            _ = try await currentUser
        } catch {
            log.warning("current user unavailable, permissions unknown: \(error.localizedDescription)", category: .api)
        }

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

        // An unavailable list is left out rather than reported as zero: the warning above already
        // says it could not be read, and "0 tags" would claim the server has none.
        log.info(
            (
                ["cache updated in \(Self.formatted(started.duration(to: clock.now)))"]
                    + [
                        (tagsCount, "tag"),
                        (correspondentsCount, "correspondent"),
                        (documentTypesCount, "document type"),
                        (savedViewsCount, "saved view"),
                        (storagePathsCount, "storage path"),
                        (customFieldsCount, "custom field"),
                    ]
                    .compactMap { count, noun in count.map { Self.pluralised($0, noun) } }
            )
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
