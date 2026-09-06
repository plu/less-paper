@testable import ShareFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ShareFormViewTests {

    // The shape perm-doc-importer reproduces: able to import, able to list nothing. The pickers sit
    // in the rendered body, so this image discriminates where toolbar chrome would not.
    @Test
    func testSnapshot_pickersHidden() async throws {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .addDocument] }

        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(server: server),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "pickersHidden"
        )
    }

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $servers.withLock {
            $0 = [
                .testValue(id: "1"),
                .testValue(id: "2")
            ]
        }

        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "multiple_servers"
        )

        assertSnapshot(
            of: ShareFormView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        ShareFormReducer()
                    }
                )
            )
            .environment(\.sizeCategory, .accessibilityLarge)
            .frame(width: 375),
            as: .image(layout: .device(config: .iPhone12)),
            named: "accessibilityLarge"
        )
    }
}
