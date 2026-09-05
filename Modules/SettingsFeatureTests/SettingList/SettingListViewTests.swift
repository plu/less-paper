@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import SwiftSharing
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SettingListViewTests {
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: SettingListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        SettingListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // 2400pt is taller than the list is today, which is the whole point: a row added past it is
    // clipped away silently and the reference still matches. Grow the height when the list grows.
    @Test
    func testSnapshot_fullList() async throws {
        assertSnapshot(
            of: SettingListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        SettingListReducer()
                    }
                )
            ),
            as: .image(layout: .fixed(width: 390, height: 2400)),
            named: "full-list"
        )
    }

    // Seeding the cache explicitly, never leaving it nil: a nil cache fails open and renders every
    // row, which would make a "gated" snapshot identical to an ungated one and prove nothing.
    // PDF passwords and trash must still appear here - they have no server permission and must
    // never be gated.
    @Test
    func testSnapshot_viewTagOnly() async throws {
        let server = seedPermissions([.viewTag])

        assertSnapshot(
            of: SettingListView(
                store: Store(
                    initialState: .testValue(server: server),
                    reducer: {
                        SettingListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_noPermissions() async throws {
        let server = seedPermissions([])

        assertSnapshot(
            of: SettingListView(
                store: Store(
                    initialState: .testValue(server: server),
                    reducer: {
                        SettingListReducer()
                    }
                )
            ),
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
