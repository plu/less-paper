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

    // Read this before "fixing" the search field in these references.
    //
    // Every reference here renders `DocumentListView` on its own. The running app never does: it is
    // embedded in `MainView`'s `TabView`, and on iOS 27 that is what makes the search field appear
    // at the top, in the navigation bar's search drawer — observed live, and what
    // `DocumentListScreen.search(for:)` drives. Rendered without that container the field falls to
    // the bottom of the screen, so the status pill can land next to or over it.
    //
    // That proximity is an artefact of the harness and not a bug. It was once "fixed" by widening
    // the pill's overlay into a full-width opaque band, which cost every user ~38pt of the last row
    // permanently and unscrollably to hide a collision none of them could ever see. The band was
    // removed; do not re-add it, and do not add padding, an inset or a background here to make
    // these references look tidier. If the pill ever needs changing, the case has to come from the
    // app, not from a PNG of a view rendered outside its container.
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
