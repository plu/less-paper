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
struct DocumentFilterTagFieldTests {
    @Test(
        arguments: DocumentFilterTagRule.allCases
    )
    func testSnapshot(rule: DocumentFilterTagRule) async throws {
        let values = [ApiInterface.Tag].previewValue
        let tag1 = try #require(values[safe: 0])
        let tag2 = try #require(values[safe: 1])
        let tag3 = try #require(values[safe: 2])

        assertSnapshot(
            of: DocumentFilterTagField.testValue(
                rule: rule,
                selection: .testValue(
                    all: .testValue(
                        exclude: Set([tag1]),
                        include: Set([tag2])
                    ),
                    any: Set([tag3])
                )
            ).frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: rule.rawValue
        )
    }
}

extension DocumentFilterTagField {
    static func testValue(
        rule: DocumentFilterTagRule = .all,
        selection: DocumentFilterTagSelection = .testValue()
    ) -> Self {
        .init(
            rule: rule,
            selection: selection
        )
    }
}
