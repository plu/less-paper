@testable import DocumentsFeature

import ApiInterface
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

    // Read this before "fixing" the status pill's neighbours in these references.
    //
    // Every reference here renders `DocumentListView` on its own; the running app never does, it is
    // embedded in `MainView`'s `TabView`. Anything that looks crowded near the pill is an artefact
    // of the harness rather than a bug. It was once "fixed" by widening the pill's overlay into a
    // full-width opaque band, which cost every user ~38pt of the last row permanently and
    // unscrollably to hide a collision none of them could ever see. The band was removed; do not
    // re-add it, and do not add padding, an inset or a background here to make these references
    // look tidier. If the pill ever needs changing, the case has to come from the app, not from a
    // PNG of a view rendered outside its container.
    //
    // The first row is the search field itself, and it is the first row in both modes — see
    // `testSnapshot_searching` for what the rows underneath it become.
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

    // The other half of the list. Everything here is what the reference has to show: the field is
    // still the first row and now carries a Cancel beside it, the result sections have replaced the
    // document cards, the tip invitation is hidden although it is eligible, and the status pill is
    // gone although `documents` and `totalNumberOfDocuments` are both still set.
    @Test
    func testSnapshot_searching() async throws {
        var state = DocumentListReducer.State.testValue(
            isLoaded: true,
            search: .testValue(
                results: .testValue(
                    correspondents: [.testValue(id: 4)],
                    documents: [
                        .testValue(id: 1, title: "Puky"),
                        .testValue(id: 2, title: "W-8BEN"),
                    ],
                    tags: [.testValue(id: 7, name: "Manual")]
                ),
                searchText: "man"
            )
        )
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

    // An empty library while a query is in play. Without the guard in `DocumentListEmptyView` this
    // reference would show "No documents found" over the results.
    @Test
    func testSnapshot_searchingWithAnEmptyLibrary() async throws {
        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        documents: [],
                        isLoaded: true,
                        search: .testValue(
                            results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
                            searchText: "man"
                        ),
                        totalNumberOfDocuments: 0
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
    func testSnapshot_searchingDarkMode() async throws {
        assertSnapshot(
            of: DocumentListView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(
                        search: .testValue(
                            results: .testValue(
                                documents: [.testValue(id: 1, title: "Puky")],
                                tags: [.testValue(id: 7, name: "Manual")]
                            ),
                            searchText: "man"
                        )
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
