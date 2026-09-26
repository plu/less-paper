@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SearchBarTests {

    // Nothing typed and nothing focused: no cancel button, and no clear button inside the field.
    // The cancel button is still in the hierarchy, collapsed to zero width — see the note in
    // SearchBar — so this reference is what catches it being put back inside an `if`.
    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: SearchBar(text: .constant(""), cancelled: {})
                .frame(width: 375)
                .padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    // Text present. Both ways out are on screen and they are not the same: the clear button inside
    // the field wipes the text and leaves the keyboard up, and the cancel button beside it finishes
    // the search.
    @Test
    func testSnapshot_withText() async throws {
        assertSnapshot(
            of: SearchBar(text: .constant("Invoice"), cancelled: {})
                .frame(width: 375)
                .padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
