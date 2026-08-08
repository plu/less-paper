@testable import ComposableArchitecture
@testable import DocumentsFeature

import ApiInterface
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFilterSortFieldTests {
    @Test(
        arguments: SortDirection.allCases
    )
    func testSnapshot_direction(direction: SortDirection) async throws {
        assertSnapshot(
            of: DocumentFilterSortField.testValue(
                direction: direction
            ).frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: String(describing: direction)
        )
    }

    @Test(
        arguments: SortField.allCases
    )
    func testSnapshot_field(field: SortField) async throws {
        assertSnapshot(
            of: DocumentFilterSortField.testValue(
                field: field
            ).frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: field.rawValue
        )
    }
}

extension DocumentFilterSortField {
    static func testValue(
        direction: SortDirection = .descending,
        field: SortField = .added,
        onViewAction: @escaping (DocumentFilterReducer.Action.View) -> StoreTask = { _ in .init(rawValue: nil) }
    ) -> Self {
        .init(
            direction: direction,
            field: field,
            onViewAction: onViewAction
        )
    }
}
