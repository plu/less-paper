@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TitleFieldTests {

    // Without an action the field must render exactly as it did before the button existed, which is
    // what keeps the ShareFormView and bulk-edit references valid.
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                TitleField(text: .constant(""))
                TitleField(text: .constant("Electricity bill — August 2024"))
            }
            .frame(width: 375)
            .padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    @Test
    func testSnapshot_withSuggestButton() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                TitleField(text: .constant(""), suggestButtonTapped: {})
                // The button stays once there is text: renaming a badly titled document is the case
                // this feature is for, unlike ASN, whose button hides for the opposite reason.
                TitleField(text: .constant("scan_20240817_113052"), suggestButtonTapped: {})
            }
            .frame(width: 375)
            .padding(),
            as: .image(layout: .sizeThatFits),
            named: "withSuggestButton"
        )
    }
}
