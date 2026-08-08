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
struct DateFieldPopoverTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                DateFieldPopover(
                    title: "Created date",
                    value: .constant(Date(timeIntervalSince1970: 1609459200)),
                    suggestions: .constant([
                        .init(date: Date(timeIntervalSince1970: 1609459200)),
                        .init(date: Date(timeIntervalSince1970: 1609559200)),
                        .init(date: Date(timeIntervalSince1970: 1609659200)),
                    ])
                )

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    DateFieldPopover(
                        title: "Created date",
                        value: .constant(Date(timeIntervalSince1970: 1609459200)),
                        suggestions: .constant([
                            .init(date: Date(timeIntervalSince1970: 1609459200)),
                            .init(date: Date(timeIntervalSince1970: 1609559200)),
                            .init(date: Date(timeIntervalSince1970: 1609659200)),
                        ])
                    )
                    .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
