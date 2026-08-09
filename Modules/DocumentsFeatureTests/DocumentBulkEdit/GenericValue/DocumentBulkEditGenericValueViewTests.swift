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
struct DocumentBulkEditGenericValueViewTests {

    @Test
    func testSnapshot_unedited() async throws {
        assertSnapshot(
            of: DocumentBulkEditGenericValueView<Correspondent>(
                store: Store(
                    initialState: DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
                        documentCounts: [1: 2, 2: 1],
                        documents: [10, 11]
                    ),
                    reducer: {
                        EmptyReducer<
                            DocumentBulkEditGenericValueReducer<Correspondent>.State,
                            DocumentBulkEditGenericValueReducer<Correspondent>.Action
                        >()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unedited"
        )
    }

    @Test
    func testSnapshot_edited() async throws {
        assertSnapshot(
            of: DocumentBulkEditGenericValueView<Correspondent>(
                store: Store(
                    initialState: DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
                        documentCounts: [1: 2, 2: 1],
                        documents: [10, 11],
                        operation: .assign(2)
                    ),
                    reducer: {
                        EmptyReducer<
                            DocumentBulkEditGenericValueReducer<Correspondent>.State,
                            DocumentBulkEditGenericValueReducer<Correspondent>.Action
                        >()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "edited"
        )
    }
}
