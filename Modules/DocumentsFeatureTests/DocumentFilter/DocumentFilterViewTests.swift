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

    @Test
    func testSnapshot_matchCount() async throws {
        @Shared(.documentFilterMatchCount)
        var matchCount

        $matchCount.withLock { $0 = .init(count: 77) }

        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego")
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCount"
        )
    }

    @Test
    func testSnapshot_matchCountRecalculating() async throws {
        @Shared(.documentFilterMatchCount)
        var matchCount

        $matchCount.withLock { $0 = .init(count: 77, isRecalculating: true) }

        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego")
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCountRecalculating"
        )
    }

    @Test
    func testSnapshot_matchCountSingular() async throws {
        @Shared(.documentFilterMatchCount)
        var matchCount

        $matchCount.withLock { $0 = .init(count: 1) }

        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego")
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCountSingular"
        )
    }

    @Test
    func testSnapshot_matchCountInTagPicker() async throws {
        @Shared(.documentFilterMatchCount)
        var matchCount

        $matchCount.withLock { $0 = .init(count: 12) }

        assertSnapshot(
            of: DocumentFilterTagListView(
                store: Store(
                    initialState: DocumentFilterTagListReducer.State.testValue(
                        values: [
                            .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
                            .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000")
                        ]
                    ),
                    reducer: {
                        DocumentFilterTagListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCountInTagPicker"
        )
    }
}
