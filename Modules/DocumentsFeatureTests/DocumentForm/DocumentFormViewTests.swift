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
struct DocumentFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: DocumentFormView(
                store: Store(
                    initialState: DocumentFormReducer.State.testValue(),
                    reducer: {
                        DocumentFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
