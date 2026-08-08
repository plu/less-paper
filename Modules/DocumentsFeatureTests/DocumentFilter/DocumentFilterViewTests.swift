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
struct DocumentFilterViewTests {

    @Test
    func testSnapshot_allDocuments() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .init()
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_modified() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(
                            correspondent: .init(selection: [.testValue()]),
                            documentType: .init(rule: .exclude, selection: [.testValue()]),
                            searchValue: "Lego"
                        )
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_savedView() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .init(),
                        savedView: .testValue()
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_savedView_modified() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .init(searchValue: "Lego"),
                        savedView: .testValue()
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
