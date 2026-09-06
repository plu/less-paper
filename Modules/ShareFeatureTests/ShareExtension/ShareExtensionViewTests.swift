@testable import ShareFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ShareExtensionViewTests {

    @Test
    func testSnapshot_importFailed() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let store = Store(
            initialState: .testValue(
                input: .extensionContext(nil)
            ),
            reducer: {
                ShareExtensionReducer()
            }
        )
        store.send(.view(.onAppear))

        assertSnapshot(
            of: ShareExtensionView(
                store: store
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Seeded explicitly: a nil cache fails open and renders the ordinary form, which would make
    // this snapshot identical to an ungated one and prove nothing.
    @Test
    func testSnapshot_importNotPermitted() async throws {
        let server = Server.testValue(alias: "work")

        @Shared(.selectedServer)
        var selectedServer: Server? = server

        @Shared(.permissions(server))
        var permissions: [Permission]?

        @Shared(.currentUser(server))
        var currentUser: User?

        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        let store = Store(
            initialState: .testValue(
                input: .extensionContext(TestExtensionContext.testValue())
            ),
            reducer: {
                ShareExtensionReducer()
            }
        )
        store.send(.view(.onAppear))

        assertSnapshot(
            of: ShareExtensionView(
                store: store
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_missingServer() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server?
        let store = Store(
            initialState: .testValue(
                input: .extensionContext(TestExtensionContext.testValue())
            ),
            reducer: {
                ShareExtensionReducer()
            }
        )
        store.send(.view(.onAppear))

        assertSnapshot(
            of: ShareExtensionView(
                store: store
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
