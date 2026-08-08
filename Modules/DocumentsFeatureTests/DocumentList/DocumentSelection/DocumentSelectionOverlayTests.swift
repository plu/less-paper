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
struct DocumentSelectionOverlayTests {

    @Test
    func testSnapshot_selectionInactive() async throws {
        let selectionStore = Store(
            initialState: DocumentSelectionReducer.State(
                server: .testValue()
            )
        ) {
            DocumentSelectionReducer()
        }

        assertSnapshot(
            of: ScrollView {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(),
                        reducer: { DocumentRowReducer() }
                    )
                )
                .documentSelectionOverlay(
                    document: 1,
                    store: selectionStore
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_selectionActive_notSelected() async throws {
        let selectionStore = Store(
            initialState: DocumentSelectionReducer.State(
                allLoadedDocuments: [1],
                isActive: true,
                server: .testValue()
            )
        ) {
            DocumentSelectionReducer()
        }

        assertSnapshot(
            of: ScrollView {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(),
                        reducer: { DocumentRowReducer() }
                    )
                )
                .documentSelectionOverlay(
                    document: 1,
                    store: selectionStore
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_selectionActive_selected() async throws {
        let selectionStore = Store(
            initialState: DocumentSelectionReducer.State(
                allLoadedDocuments: [1],
                isActive: true,
                selectedDocuments: [1],
                server: .testValue()
            )
        ) {
            DocumentSelectionReducer()
        }

        assertSnapshot(
            of: ScrollView {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(),
                        reducer: { DocumentRowReducer() }
                    )
                )
                .documentSelectionOverlay(
                    document: 1,
                    store: selectionStore
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
