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
struct DocumentFilterGenericValueListViewTests {
    @Test(
        arguments: DocumentFilterGenericValueRule.allCases
    )
    func testSnapshot(rule: DocumentFilterGenericValueRule) async throws {
        assertSnapshot(
            of: DocumentFilterGenericValueListView<Correspondent>(
                store: Store(
                    initialState: DocumentFilterGenericValueListReducer.State(
                        rule: rule,
                        selection: [
                            Correspondent.testValue(id: 1, name: "C1")
                        ],
                        values: [
                            Correspondent.testValue(id: 1, name: "C1"),
                            Correspondent.testValue(id: 2, name: "C2")
                        ]
                    ),
                    reducer: {
                        DocumentFilterGenericValueListReducer()
                    }
                ),
                title: .correspondent
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: rule.rawValue
        )
    }
}
