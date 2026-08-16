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
struct DocumentBulkEditTitleViewTests {

    @Test
    func testSnapshot_initial() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadedDocuments: documents)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "initial"
        )
    }

    @Test
    func testSnapshot_edited() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                loadedDocuments: documents,
                template: "Renamed-{doc_pk}"
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "edited"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: view(state: .testValue(isLoading: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_saving() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                isSaving: true,
                loadedDocuments: documents,
                savedCount: 1,
                template: "Renamed-{doc_pk}"
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "saving"
        )
    }

    private var documents: IdentifiedArrayOf<Document> {
        [
            .testValue(id: 10, title: "Invoice 42"),
            .testValue(id: 11, title: "Scan 2026-03-11")
        ]
    }

    private func view(state: DocumentBulkEditTitleReducer.State) -> some View {
        DocumentBulkEditTitleView(
            store: Store(initialState: state) {
                EmptyReducer<
                    DocumentBulkEditTitleReducer.State,
                    DocumentBulkEditTitleReducer.Action
                >()
            }
        )
    }
}
