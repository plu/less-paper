@testable import DocumentsFeature

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
}
