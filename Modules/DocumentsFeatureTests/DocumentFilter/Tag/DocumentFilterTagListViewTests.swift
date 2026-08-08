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
struct DocumentFilterTagListViewTests {
    @Test(
        arguments: DocumentFilterTagRule.allCases
    )
    func testSnapshot(rule: DocumentFilterTagRule) async throws {
        let values = [ApiInterface.Tag].previewValue
        let tag1 = try #require(values[safe: 0])
        let tag2 = try #require(values[safe: 1])
        let tag3 = try #require(values[safe: 2])

        assertSnapshot(
            of: DocumentFilterTagListView(
                store: Store(
                    initialState: DocumentFilterTagListReducer.State(
                        rule: rule,
                        selection: .testValue(
                            all: .testValue(
                                exclude: Set([tag1]),
                                include: Set([tag2])
                            ),
                            any: Set([tag3])
                        ),
                        values: .init(uniqueElements: values)
                    ),
                    reducer: {
                        DocumentFilterTagListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: rule.rawValue
        )
    }
}
