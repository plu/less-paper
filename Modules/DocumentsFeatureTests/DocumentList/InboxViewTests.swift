@testable import DocumentsFeature

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
struct InboxViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Dark mode: `m3SurfaceContainerLowest` and the default list row background are both white in
    // light mode, so a row that never sets `listRowBackground` only shows up against dark.
    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    @Test
    func testSnapshot_emptyResultDarkMode() async throws {
        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [],
                        filter: .testValue(isInbox: true),
                        isLoaded: true
                    ),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    // The badge is the only thing on the inbox that reports a failed import, so it gets its own
    // reference rather than riding along on the default one.
    @Test
    func testSnapshot_withFailedFileTasks() async throws {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 3 }

        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // A button whose only possible outcome is a 403 is worse than no button, so it has to be
    // absent rather than merely disabled.
    @Test
    func testSnapshot_withoutViewPaperlessTaskPermission() async throws {
        let server = Server.testValue()
        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(server: server),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
