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
}
