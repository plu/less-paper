@testable import TagsFeature

import ApiInterface
import ComposableArchitecture
import SwiftSharing
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getTags.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TagListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    // Dark mode: `m3SurfaceContainerLowest` and the default list row background are both white in
    // light mode, so a row that never sets `listRowBackground` only shows up against dark.
    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    // Seeding the cache explicitly, never leaving it nil: a nil cache fails open and renders every
    // control, which would make a "gated" snapshot identical to an ungated one and prove nothing.
    @Test
    func testSnapshot_viewOnly() async throws {
        let server = seedPermissions([.viewTag])

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(server: server, tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_viewAndChangeTag() async throws {
        let server = seedPermissions([.viewTag, .changeTag])

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(server: server, tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_viewAndDeleteTag() async throws {
        let server = seedPermissions([.viewTag, .deleteTag])

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(server: server, tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_viewOnly_empty() async throws {
        let server = seedPermissions([.viewTag])

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(server: server),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Nothing read yet, so nothing to gate on: this should look exactly like `testSnapshot` above.
    @Test
    func testSnapshot_nilCache() async throws {
        let server = seedPermissions(nil)

        assertSnapshot(
            of: NavigationStack { TagListView(
                store: Store(
                    initialState: .testValue(server: server, tags: .previewValue),
                    reducer: {
                        TagListReducer()
                    }
                )
            )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    private func seedPermissions(_ permissions: [Permission]?) -> Server {
        let server = Server.testValue()

        @Shared(.currentUser(server))
        var cachedUser: User?

        @Shared(.permissions(server))
        var cachedPermissions: [Permission]?

        $cachedUser.withLock { $0 = .testValue(isSuperuser: false) }
        $cachedPermissions.withLock { $0 = permissions }

        return server
    }
}
