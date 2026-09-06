@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import TestSupport
import UIKit

@MainActor
@Suite(
    // Every view here fires .task { await send(.onAppear).finish() }, which runs runRefresh. The
    // result never lands before a synchronous snapshot capture - TagListViewTests relies on the
    // same thing - but the call still has to go somewhere, or the unimplemented default records a
    // failure regardless of timing.
    .dependencies {
        $0.updateCache.execute = { _ in }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ServerDetailViewTests {

    // The masking decision is only as good as something that fails when a field prints a raw value,
    // and this screen will accumulate fields. Two servers differing in every secret-bearing input
    // the app holds must be indistinguishable on screen; if any one of them reaches the output,
    // these two images stop matching.
    //
    // "Every input" is the part that matters, and the part this test used to get wrong. Varying
    // only the header value is why a URL leak - absoluteString round-trips userinfo, so
    // https://user:s3cr3t@host printed the password - stayed green through several reviews. The
    // three inputs varied here are the three the app can hold a credential in: userinfo embedded
    // in Server.url, a custom header's value, and the keychain token behind the auth mode row.
    // Only the alias and the host are held constant, because those are what the screen is
    // supposed to print.
    //
    // Rendered with the same Snapshotting<SwiftUI.View, UIImage>.image strategy every other view
    // test in this module asserts with (see TestSupport's `assertSnapshot`), rather than
    // ImageRenderer: this is the rasteriser the repo has already proven handles a List body, and
    // reusing it means the two images are captured exactly the way a recorded reference would be.
    @Test
    func twoDifferentSecretsRenderIdentically() async throws {
        func image(url: String, headerValue: String, token: String) async throws -> Data {
            let server = Server.testValue(
                headers: [HTTPHeader.testValue(name: "X-Api-Key", value: headerValue)],
                url: .testValue(string: url)
            )
            let view = withDependencies {
                $0.authenticationProvider.getToken = { _ in token }
            } operation: {
                ServerDetailView(
                    store: Store(initialState: ServerDetailReducer.State(server: server)) {
                        ServerDetailReducer()
                    }
                )
            }

            let uiImage = await withCheckedContinuation { continuation in
                Snapshotting<AnyView, UIImage>.image(layout: .fixed(width: 390, height: 3600))
                    .snapshot(AnyView(view))
                    .run { continuation.resume(returning: $0) }
            }

            return try #require(uiImage.pngData())
        }

        // One URL carries credentials and the other carries none, so the pair also proves that
        // whether userinfo is present is itself invisible - not only that its value is.
        let first = try await image(
            url: "https://operator:s3cr3t@paperless.example.com:8000/",
            headerValue: "SECRET-ONE",
            token: "TOKEN-ONE"
        )
        let second = try await image(
            url: "https://paperless.example.com:8000/",
            headerValue: "A-MUCH-LONGER-SECRET-TWO",
            token: "TOKEN-TWO"
        )

        #expect(first == second)
    }

    @Test
    func testSnapshot_fullyPopulated() async throws {
        let server = Server.testValue(
            headers: [HTTPHeader.testValue(name: "X-Api-Key", value: "SECRET-VALUE")]
        )

        @Shared(.apiVersion(server)) var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "2.10.2" }

        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock {
            $0 = .testValue(groups: [1], isStaff: true, isSuperuser: true, username: "admin")
        }

        @Shared(.permissions(server)) var permissions: [Permission]?
        $permissions.withLock { $0 = Permission.allCases }

        @Shared(.correspondents(server)) var correspondents: IdentifiedArrayOf<Correspondent>
        $correspondents.withLock { $0 = [.testValue()] }

        @Shared(.customFields(server)) var customFields: IdentifiedArrayOf<CustomField>
        $customFields.withLock { $0 = [.testValue()] }

        @Shared(.documentTypes(server)) var documentTypes: IdentifiedArrayOf<DocumentType>
        $documentTypes.withLock { $0 = [.testValue()] }

        @Shared(.groups(server)) var groups: IdentifiedArrayOf<ApiInterface.Group>
        $groups.withLock { $0 = [.testValue(id: 1, name: "Admins")] }

        @Shared(.savedViews(server)) var savedViews: IdentifiedArrayOf<SavedView>
        $savedViews.withLock { $0 = [.testValue()] }

        @Shared(.storagePaths(server)) var storagePaths: IdentifiedArrayOf<StoragePath>
        $storagePaths.withLock { $0 = [.testValue()] }

        @Shared(.tags(server)) var tags: IdentifiedArrayOf<ApiInterface.Tag>
        $tags.withLock { $0 = [.testValue()] }

        @Shared(.users(server)) var users: IdentifiedArrayOf<User>
        $users.withLock { $0 = [.testValue()] }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument>
        $favorites.withLock { $0 = [.testValue()] }

        // hasToken: true renders the auth mode row as "token" rather than the "Unknown" every
        // other fixture shows - a fixture has to seed this or the row's real values never get
        // exercised, only its fallback.
        var state = ServerDetailReducer.State.testValue(hasToken: true, server: server)
        state.statistics = .testValue()

        TestSupport.assertSnapshot(
            of: NavigationStack {
                ServerDetailView(
                    store: Store(initialState: state) {
                        ServerDetailReducer()
                    }
                )
            },
            as: .image(layout: .fixed(width: 390, height: 3600))
        )
    }

    // The case that catches a screen printing 0: nothing has ever been cached, so every
    // statistics-derived count must read "Unknown" rather than a number that looks real but isn't.
    // hasToken stays nil here too, on purpose: this is the fixture for "never resolved anything".
    @Test
    func testSnapshot_neverFetched() async throws {
        let server = Server.testValue()

        let state = ServerDetailReducer.State.testValue(server: server)

        TestSupport.assertSnapshot(
            of: NavigationStack {
                ServerDetailView(
                    store: Store(initialState: state) {
                        ServerDetailReducer()
                    }
                )
            },
            as: .image(layout: .fixed(width: 390, height: 3600))
        )
    }

    // The other half of the "unknown, never 0" rule for cache-derived counts: once this screen's
    // own refresh has succeeded, an empty cache is a known fact - the server genuinely has none -
    // and must read 0 rather than Unknown forever. Every cache-derived array is left at its default
    // [] on purpose; only statistics is set, which is the signal a refresh completed.
    @Test
    func testSnapshot_emptyCachesAfterSuccessfulRefresh() async throws {
        let server = Server.testValue()

        var state = ServerDetailReducer.State.testValue(server: server)
        state.statistics = .testValue()

        TestSupport.assertSnapshot(
            of: NavigationStack {
                ServerDetailView(
                    store: Store(initialState: state) {
                        ServerDetailReducer()
                    }
                )
            },
            as: .image(layout: .fixed(width: 390, height: 3600))
        )
    }

    @Test
    func testSnapshot_restricted() async throws {
        let server = Server.testValue()

        @Shared(.apiVersion(server)) var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "2.10.2" }

        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock {
            $0 = .testValue(groups: [], isStaff: false, isSuperuser: false, username: "restricted")
        }

        // Missing view_user on purpose: this is the permission a superuser bypass would otherwise
        // paper over, and the Permissions section must show every other type it was given.
        @Shared(.permissions(server)) var permissions: [Permission]?
        $permissions.withLock { $0 = Permission.allCases.filter { $0 != .viewUser } }

        @Shared(.correspondents(server)) var correspondents: IdentifiedArrayOf<Correspondent>
        $correspondents.withLock { $0 = [.testValue()] }

        @Shared(.customFields(server)) var customFields: IdentifiedArrayOf<CustomField>
        $customFields.withLock { $0 = [.testValue()] }

        @Shared(.documentTypes(server)) var documentTypes: IdentifiedArrayOf<DocumentType>
        $documentTypes.withLock { $0 = [.testValue()] }

        @Shared(.savedViews(server)) var savedViews: IdentifiedArrayOf<SavedView>
        $savedViews.withLock { $0 = [.testValue()] }

        @Shared(.storagePaths(server)) var storagePaths: IdentifiedArrayOf<StoragePath>
        $storagePaths.withLock { $0 = [.testValue()] }

        @Shared(.tags(server)) var tags: IdentifiedArrayOf<ApiInterface.Tag>
        $tags.withLock { $0 = [.testValue()] }

        @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument>
        $favorites.withLock { $0 = [.testValue()] }

        // Users and groups stay empty on purpose - the restriction under test.

        // hasToken: false renders the auth mode row as "remote-user" - the other real value,
        // alongside fullyPopulated's "token", so both non-Unknown outcomes are exercised somewhere.
        var state = ServerDetailReducer.State.testValue(hasToken: false, server: server)
        state.statistics = .testValue()

        TestSupport.assertSnapshot(
            of: NavigationStack {
                ServerDetailView(
                    store: Store(initialState: state) {
                        ServerDetailReducer()
                    }
                )
            },
            as: .image(layout: .fixed(width: 390, height: 3600))
        )
    }
}
