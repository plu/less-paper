@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import DesignTokens
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentSearchResultsViewTests {

    // Wrapped in a `List` because the view's body is a set of `Section`s, which only render as rows
    // inside a list container — a bare render would record a reference that looks nothing like the
    // screen. The wrapper below is the documents list's own container, so these references show
    // production chrome as well as content and section order.
    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            results: .testValue(
                                correspondents: [.testValue(id: 4)],
                                customFields: [.testValue(id: 2, name: "Reference")],
                                documents: [
                                    .testValue(id: 1, title: "Puky"),
                                    .testValue(id: 2, title: "W-8BEN"),
                                ],
                                documentTypes: [.testValue(id: 5)],
                                savedViews: [.testValue()],
                                storagePaths: [.testValue(id: 3)],
                                tags: [.testValue(id: 7, name: "Manual")]
                            ),
                            searchText: "man"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // The production case: the server matches a couple of types and nothing else. An empty
    // `ForEach` renders no rows, but a `Section` with a header is free to render the header anyway,
    // which would leave five captions standing over nothing.
    @Test
    func testSnapshot_partiallyPopulated() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            results: .testValue(
                                documents: [.testValue(id: 1, title: "Puky")],
                                tags: [.testValue(id: 7, name: "Manual")]
                            ),
                            searchText: "man"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_noResults() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            results: .testValue(),
                            searchText: "zzz"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // A first search that fails has no results to fall back on, so without this branch the overlay
    // renders nothing at all and a lost network looks like never having searched.
    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            error: "The Internet connection appears to be offline.",
                            searchText: "man"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // A re-search that fails: the reducer deliberately leaves the previous results standing, so
    // what renders is still the sections and not the error. This reference is the regression test
    // for an error branch that was briefly unguarded and wiped the list the user was reading.
    @Test
    func testSnapshot_errorKeepsPreviousResults() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            error: "The Internet connection appears to be offline.",
                            results: .testValue(
                                documents: [.testValue(id: 1, title: "Puky")],
                                tags: [.testValue(id: 7, name: "Manual")]
                            ),
                            searchText: "man"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: searchResultsList {
                DocumentSearchResultsView(
                    store: Store(
                        initialState: DocumentSearchReducer.State.testValue(
                            isLoading: true,
                            searchText: "man"
                        ),
                        reducer: {
                            DocumentSearchReducer()
                        }
                    )
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Matches DocumentListView's container exactly, `listStyle(.plain)` included; a reference
    // recorded against a differently styled list would say nothing about what the list shows.
    private func searchResultsList(@ViewBuilder content: () -> some View) -> some View {
        List {
            content()
        }
        .background(Color.m3SurfaceContainerLowest)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
