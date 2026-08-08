@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ColorTests {
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: Color.previewValue.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
        )
    }
}
