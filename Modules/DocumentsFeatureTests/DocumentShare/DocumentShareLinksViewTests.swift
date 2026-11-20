@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Dependencies
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentShareLinksViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(state: .testValue(links: Self.links, server: Self.server)),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_accessibilityXXL() async throws {
        assertSnapshot(
            of: view(state: .testValue(links: Self.links, server: Self.server))
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge),
            as: .image(layout: .device(config: .iPhone12)),
            named: "accessibilityXXL"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(links: [], server: Self.server)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_empty_accessibilityXXL() async throws {
        assertSnapshot(
            of: view(state: .testValue(links: [], server: Self.server))
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge),
            as: .image(layout: .device(config: .iPhone12)),
            named: "emptyAccessibilityXXL"
        )
    }

    @Test
    func testSnapshot_loadError() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "The request timed out.", server: Self.server)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loadError"
        )
    }

    @Test
    func testSnapshot_noArchive() async throws {
        assertSnapshot(
            of: view(state: .testValue(hasArchiveVersion: false, links: Self.links, server: Self.server)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "noArchive"
        )
    }

    @Test
    func testSnapshot_withoutDeletePermission() async throws {
        assertSnapshot(
            of: view(state: withoutDeletePermission()),
            as: .image(layout: .device(config: .iPhone12)),
            named: "withoutDeletePermission"
        )
    }

    // Fixed rather than the default test server, whose URL comes from TUIST_PAPERLESS_TEST_URL and
    // differs between CI and a local checkout.
    private static let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)

    // The fixed clock from testDependencies: 6 days ahead of it reads "in 6 days".
    private static let links: IdentifiedArrayOf<ApiInterface.ShareLink> = [
        .testValue(
            expiration: Date(timeIntervalSince1970: 1234567890 + 6 * 86400),
            id: 1,
            slug: "aB3x9Q"
        ),
        .testValue(expiration: nil, id: 2, slug: "K7pLmZ"),
    ]

    // Seeded before the state is built: ServerPermissions reads the shared caches on init.
    private func withoutDeletePermission() -> DocumentShareLinksReducer.State {
        let server = Self.server

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.addShareLink] }

        return .testValue(links: Self.links, server: server)
    }

    private func view(state: DocumentShareLinksReducer.State) -> some View {
        DocumentShareLinksView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentShareLinksReducer()
                }
            )
        )
    }
}
