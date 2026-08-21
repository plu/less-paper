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
                URLFieldHarness(url: URL(string: "https://localhost:8000")!)

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    URLFieldHarness(url: URL(string: "https://localhost:8000")!)
                        .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}

// URLField needs a FocusState binding, and @FocusState is only valid inside a View.
private struct URLFieldHarness: View {
    var body: some View {
        URLField(url: .constant(url), focus: $focus, equals: .address)
    }

    let url: URL

    @FocusState
    private var focus: Focus?

    private enum Focus {
        case address
    }
}
