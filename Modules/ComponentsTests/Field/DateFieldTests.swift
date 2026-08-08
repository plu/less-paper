@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DateFieldTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                DateField(
                    title: "Created date",
                    value: .constant(Date(timeIntervalSince1970: 1609459200)),
                    suggestions: .constant([])
                )

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    DateField(
                        title: "Created date",
                        value: .constant(Date(timeIntervalSince1970: 1609459200)),
                        suggestions: .constant([])
                    )
                    .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
