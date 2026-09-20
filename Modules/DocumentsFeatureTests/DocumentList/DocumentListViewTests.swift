@testable import DocumentsFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: DocumentListView(
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
            of: DocumentListView(
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
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [],
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

    @Test
    func testSnapshot_emptyResult() async throws {
        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [],
                        isLoaded: true
                    ),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_errorResult() async throws {
        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [],
                        error: "Something went wrong",
                        isLoaded: true
                    ),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_isLoadingMore() async throws {
        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [.testValue()],
                        isLoadingMore: true
                    ),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // The invitation is the only thing in the app that mentions the tip jar outside Settings, and it
    // has to read as one more card in the stack rather than a panel bolted above it.
    @Test
    func testSnapshot_withTipInvitation() async throws {
        var state = DocumentListReducer.State.testValue()
        state.isTipInvitationVisible = true

        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: state,
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
