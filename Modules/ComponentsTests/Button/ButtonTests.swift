@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ButtonTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
                    ForEach(ButtonType.allCases, id: \.self) { type in
                        Button {} label: { Text("Regular").frame(maxWidth: .infinity) }
                            .buttonStyle(ButtonStyle(isLoading: .constant(false), size: .regular, type: type))
                            .environment(\.sizeCategory, sizeCategory)
                    }
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: "regular"
        )

        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
                    ForEach(ButtonType.allCases, id: \.self) { type in
                        Button {} label: { Text("Disabled").frame(maxWidth: .infinity) }
                            .buttonStyle(ButtonStyle(isLoading: .constant(false), size: .regular, type: type))
                            .environment(\.sizeCategory, sizeCategory)
                            .disabled(true)
                    }
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: "disabled"
        )

        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
                    ForEach(ButtonType.allCases, id: \.self) { type in
                        Button {} label: { Text("Small").frame(maxWidth: .infinity) }
                            .buttonStyle(ButtonStyle(isLoading: .constant(false), size: .small, type: type))
                            .environment(\.sizeCategory, sizeCategory)
                    }
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits),
            named: "small"
        )
    }
}
