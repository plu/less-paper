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
struct DocumentDetailViewTests {

    @Test
    func testSnapshot_success() async throws {
        let data = try Data.testValue()
        let url = URL.testValue()

        assertSnapshot(
            of: DocumentDetailView(
                store: Store(
                    initialState: DocumentDetailReducer.State.testValue(
                        downloadResult: .success(data: data, url: url)
                    ),
                    reducer: {
                        DocumentDetailReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_failure() async throws {
        assertSnapshot(
            of: DocumentDetailView(
                store: Store(
                    initialState: DocumentDetailReducer.State.testValue(
                        downloadResult: .failure("Something went wrong")
                    ),
                    reducer: {
                        DocumentDetailReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
