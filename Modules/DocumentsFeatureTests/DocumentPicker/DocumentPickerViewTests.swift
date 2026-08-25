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
struct DocumentPickerViewTests {

    @Test(
        arguments: [
            ("empty", [Document](), [Document](), ""),
            ("results", [puky, invoice], [], ""),
            // The behaviour this picker turns on: a selected document stays listed and removable
            // even once the query stops matching it.
            ("selectedPinned", [invoice], [puky], "invoice"),
            ("allSelected", [puky, invoice], [puky, invoice], ""),
            ("noResults", [], [], "zzz"),
        ]
    )
    func snapshot(
        name: String,
        documents: [Document],
        selection: [Document],
        searchText: String
    ) async throws {
        let state = DocumentPickerReducer.State.testValue(
            documents: IdentifiedArray(uniqueElements: documents),
            searchText: searchText,
            selection: IdentifiedArray(uniqueElements: selection)
        )

        assertSnapshot(
            of: DocumentPickerView(
                store: Store(initialState: state) {
                    // Empty reducer: `.task { send(.onAppear) }` would otherwise fire a search and
                    // replace the fixture rows mid-snapshot.
                    EmptyReducer()
                }
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: name
        )
    }
}

// File scope rather than statics on the suite: the suite is `@MainActor`, and a `@Test`
// `arguments:` expression is evaluated outside that isolation.
private let invoice = Document.testValue(id: 11, title: "Invoice 2026-08")

private let puky = Document.testValue(id: 10, title: "Puky-Locked")
