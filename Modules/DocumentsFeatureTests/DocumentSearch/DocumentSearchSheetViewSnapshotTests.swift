@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

// Pins the sheet's chrome — the header with its close button, and the field above the results —
// which `DocumentSearchResultsViewTests` cannot see: those render the results view on its own.
@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentSearchSheetViewSnapshotTests {

    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: DocumentSearchSheetView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(
                        results: .testValue(
                            correspondents: [.testValue(id: 4)],
                            documents: [
                                .testValue(id: 1, title: "Puky"),
                                .testValue(id: 2, title: "W-8BEN"),
                            ],
                            tags: [.testValue(id: 7, name: "Manual")]
                        ),
                        searchText: "man"
                    ),
                    reducer: {
                        DocumentSearchReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: DocumentSearchSheetView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(),
                    reducer: {
                        DocumentSearchReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: DocumentSearchSheetView(
                store: Store(
                    initialState: DocumentSearchReducer.State.testValue(
                        results: .testValue(tags: [.testValue(id: 7, name: "Manual")]),
                        searchText: "man"
                    ),
                    reducer: {
                        DocumentSearchReducer()
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
