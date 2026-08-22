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
struct DocumentBulkEditMergeViewTests {

    @Test
    func testSnapshot_loaded() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loaded"
        )
    }

    @Test
    func testSnapshot_deleteOriginals() async throws {
        assertSnapshot(
            of: view(state: .testValue(deleteOriginals: true, documents: documents)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "deleteOriginals"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: [], isLoading: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_saving() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents, isSaving: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "saving"
        )
    }

    // Dark mode: the rows set `listRowBackground` explicitly, and in light mode `m3Surface` and the
    // system default are both white, so only dark shows whether that is actually applied.
    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: view(state: .testValue(documents: documents)),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "darkMode"
        )
    }

    private var documents: [Document] {
        [
            .testValue(id: 1, title: "Invoice January"),
            .testValue(id: 2, title: "Invoice February"),
            .testValue(id: 3, title: "Invoice March")
        ]
    }

    private func view(state: DocumentBulkEditMergeReducer.State) -> some View {
        DocumentBulkEditMergeView(
            store: Store(initialState: state) {
                EmptyReducer<
                    DocumentBulkEditMergeReducer.State,
                    DocumentBulkEditMergeReducer.Action
                >()
            }
        )
    }
}
