@testable import ComposableArchitecture
@testable import DocumentsFeature

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentFilterSearchFieldTests {
    @Test(
        arguments: DocumentFilterSearchType.allCases
    )
    func testSnapshot(searchType: DocumentFilterSearchType) async throws {
        assertSnapshot(
            of: DocumentFilterSearchField.testValue(searchType: searchType),
            as: .image(layout: .device(config: .iPhone12)),
            named: searchType.rawValue
        )
    }

    @Test(
        arguments: DocumentFilterASNType.allCases
    )
    func testSnapshot_asn(asnType: DocumentFilterASNType) async throws {
        assertSnapshot(
            of: DocumentFilterSearchField.testValue(
                asnType: asnType,
                searchType: .asn
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: asnType.rawValue
        )
    }
}

extension DocumentFilterSearchField {
    static func testValue(
        asnType: DocumentFilterASNType = .equals,
        onViewAction: @escaping (DocumentFilterReducer.Action.View) -> StoreTask = { _ in .init(rawValue: nil) },
        searchType: DocumentFilterSearchType = .titleContent,
        searchValue: Binding<String> = .constant("")
    ) -> Self {
        .init(
            asnType: asnType,
            onViewAction: onViewAction,
            searchType: searchType,
            searchValue: searchValue
        )
    }
}
