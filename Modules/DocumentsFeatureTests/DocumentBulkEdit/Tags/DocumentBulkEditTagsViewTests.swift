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
struct DocumentBulkEditTagsViewTests {

    @Test
    func testSnapshot_unedited() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documentCounts: [1: 2, 2: 1],
                documents: [10, 11],
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unedited"
        )
    }

    @Test
    func testSnapshot_edited() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documentCounts: [1: 2, 2: 1],
                documents: [10, 11],
                operations: [1: .remove, 3: .add],
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "edited"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                isLoading: true,
                values: []
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                searchText: "nothing matches",
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    private var values: IdentifiedArrayOf<ApiInterface.Tag> {
        [
            .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
            .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000"),
            .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
        ]
    }

    private func view(state: DocumentBulkEditTagsReducer.State) -> some View {
        DocumentBulkEditTagsView(
            store: Store(initialState: state) {
                EmptyReducer<
                    DocumentBulkEditTagsReducer.State,
                    DocumentBulkEditTagsReducer.Action
                >()
            }
        )
    }
}
