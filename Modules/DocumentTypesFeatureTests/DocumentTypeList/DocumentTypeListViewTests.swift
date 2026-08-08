@testable import DocumentTypesFeature

import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.getDocumentTypes.execute = { _ in [] }
    },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentTypeListViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: DocumentTypeListView(
                store: Store(
                    initialState: .testValue(documentTypes: .previewValue),
                    reducer: {
                        DocumentTypeListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: DocumentTypeListView(
                store: Store(
                    initialState: .testValue(),
                    reducer: {
                        DocumentTypeListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }
}
