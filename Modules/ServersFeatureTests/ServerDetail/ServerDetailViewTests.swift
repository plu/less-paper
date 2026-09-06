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
    // Server.testValue()'s default URL comes from PAPERLESS_TEST_URL in the bundle's Info.plist,
    // which is 192.168.64.1:8000 on a developer machine and localhost:9000 on CI - and this screen
    // renders the URL, so references recorded with the default only match the machine that
    // recorded them. Every fixture here pins it instead.
    private static let fixtureURL = URL(string: "https://paperless.example.com")!

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

    // The glyph mapping, not the accessibility label: asserting a rendered SwiftUI accessibility
    // label needs a view-introspection dependency this repo does not have, and the label is a
    // straight interpolation of data other tests already cover. A wrong glyph is the likely defect
    // here, and it is invisible in a snapshot unless you know which symbol to expect.
    @Test
    func eachActionMapsToTheGlyphThisAppAlreadyUsesForIt() {
        #expect(ServerDetailView.symbol(for: "add") == "plus")
        #expect(ServerDetailView.symbol(for: "change") == "square.and.pencil")
        #expect(ServerDetailView.symbol(for: "delete") == "trash")
        #expect(ServerDetailView.symbol(for: "view") == "eye")
    }

    // A verb this app has no glyph for must fall back to its word rather than vanishing, so a
    // future paperless action stays readable.
    @Test
    func anUnknownActionHasNoGlyph() {
        #expect(ServerDetailView.symbol(for: "approve") == nil)
    }

    @Test
    func testSnapshot_fullyPopulated() async throws {
        let server = Server.testValue(
            headers: [HTTPHeader.testValue(name: "X-Api-Key", value: "SECRET-VALUE")],
            url: Self.fixtureURL
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
        // The three counts overridden here default to 0 in the shared testValue. On this screen a
        // 0 is a claim about the server, so a reference full of them is one a reader has to
        // re-derive as legitimate every time - and the rows never get exercised with a real number.
        state.statistics = .testValue(
            correspondentCount: 3,
            documentTypeCount: 2,
            storagePathCount: 1
        )

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

    // The case that catches a screen printing 0: nothing has ever been cached, so every count that
    // depends on the server must read "Unknown" rather than a number that looks real but isn't.
    // Favorites is the one row that legitimately reads 0 - nothing was ever asked of the server to
    // know that this device has none. hasToken stays nil here too, on purpose: this is the fixture
    // for "never resolved anything".
    @Test
    func testSnapshot_neverFetched() async throws {
        let server = Server.testValue(url: Self.fixtureURL)

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

    // The exception to the "empty cache reads Unknown" rule, and the fixture that stops it being
    // silently withdrawn. Every cache-derived array is left at its default [] on purpose, after a
    // refresh that completed (statistics is set): the four server-side counts still read Unknown,
    // because a completed refresh does not prove any individual list was fetched, while Favorites
    // reads 0 - it is a local store, so its emptiness is knowable without asking anyone.
    @Test
    func testSnapshot_emptyCachesReadUnknownExceptFavorites() async throws {
        let server = Server.testValue(url: Self.fixtureURL)

        var state = ServerDetailReducer.State.testValue(server: server)
        state.statistics = .testValue(
            correspondentCount: 3,
            documentTypeCount: 2,
            storagePathCount: 1
        )

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
        let server = Server.testValue(url: Self.fixtureURL)

        @Shared(.apiVersion(server)) var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "2.10.2" }

        @Shared(.currentUser(server)) var currentUser: User?
        // Member of a group whose name cannot be looked up, because /api/groups/ is one of the two
        // endpoints this account is refused. The ids are in hand and the names are not, which must
        // read Unknown - not the blank row a silent compactMap used to leave behind.
        $currentUser.withLock {
            $0 = .testValue(groups: [1], isStaff: false, isSuperuser: false, username: "restricted")
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

        // Users and groups stay empty on purpose - the restriction under test. updateCache swallows
        // the 403 each of them answers with, so nothing distinguishes a refused fetch from an empty
        // server: both counts must read Unknown rather than telling a reader this server has 0
        // users, which is the app reporting its own permission error as a fact about the server.

        // hasToken: false renders the auth mode row as "remote-user" - the other real value,
        // alongside fullyPopulated's "token", so both non-Unknown outcomes are exercised somewhere.
        var state = ServerDetailReducer.State.testValue(hasToken: false, server: server)
        state.statistics = .testValue(
            correspondentCount: 3,
            documentTypeCount: 2,
            storagePathCount: 1
        )

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

    // The failed refresh, which the spec says must cost nothing: the last known numbers stay, the
    // screen is not replaced, and a quiet note says the values are the last ones known. Before this
    // fixture existed, refreshFailed was set by the reducer, asserted by three reducer tests and
    // rendered nowhere - a flag nobody renders is a flag no test defends.
    //
    // Driven by an EmptyReducer rather than the real one: onAppear clears refreshFailed by design,
    // so a live reducer would race the capture and the note would be recorded or not depending on
    // how fast the machine is. Nothing about the reducer is under test here.
    //
    // The user belongs to no group at all, which is the other half of the Groups row: an explicit
    // None, distinct from the Unknown the restricted fixture pins for ids that cannot be resolved.
    @Test
    func testSnapshot_refreshFailed() async throws {
        let server = Server.testValue(url: Self.fixtureURL)

        @Shared(.apiVersion(server)) var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "2.10.2" }

        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock {
            $0 = .testValue(groups: [], isStaff: false, isSuperuser: false, username: "admin")
        }

        @Shared(.permissions(server)) var permissions: [Permission]?
        $permissions.withLock { $0 = Permission.allCases }

        @Shared(.customFields(server)) var customFields: IdentifiedArrayOf<CustomField>
        $customFields.withLock { $0 = [.testValue()] }

        @Shared(.users(server)) var users: IdentifiedArrayOf<User>
        $users.withLock { $0 = [.testValue()] }

        // statistics stays nil: the refresh that would have set it is the one that failed. The
        // cached counts above survive it, which is the decision this fixture records.
        var state = ServerDetailReducer.State.testValue(hasToken: true, server: server)
        state.isRefreshing = false
        state.refreshFailed = true

        TestSupport.assertSnapshot(
            of: NavigationStack {
                ServerDetailView(
                    store: Store(initialState: state) {
                        EmptyReducer<ServerDetailReducer.State, ServerDetailReducer.Action>()
                    }
                )
            },
            as: .image(layout: .fixed(width: 390, height: 3600))
        )
    }
}
