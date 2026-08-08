@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct URLFieldTests {
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                URLField(url: .constant(URL(string: "https://localhost:8000")!))

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    URLField(url: .constant(URL(string: "https://localhost:8000")!))
                        .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
