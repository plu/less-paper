@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFilterDateViewTests {

    @Test(arguments: DocumentFilterDateType.allCases)
    func testSnapshot(type: DocumentFilterDateType) async throws {
        var date = DocumentFilterInput.DateFilter()
        date.type = type

        assertSnapshot(
            of: DocumentFilterDateView(
                store: Store(
                    initialState: DocumentFilterDateReducer.State(date: date),
                    reducer: {
                        DocumentFilterDateReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: type.rawValue
        )
    }

    @Test
    func testSnapshot_withRange() async throws {
        var date = DocumentFilterInput.DateFilter()
        date.from.date = DateFormatter.filterRule.date(from: "2026-01-01")
        date.to.date = DateFormatter.filterRule.date(from: "2026-12-31")

        assertSnapshot(
            of: DocumentFilterDateView(
                store: Store(
                    initialState: DocumentFilterDateReducer.State(date: date),
                    reducer: {
                        DocumentFilterDateReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
