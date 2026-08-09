@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ConfirmationPopupViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                ConfirmationPopupView(
                    title: "Confirm assignment",
                    message: "This operation will assign the correspondent \"C1\" to 3 selected documents.",
                    cancel: {},
                    confirm: {}
                )
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_destructive() async throws {
        assertSnapshot(
            of: ScrollView {
                ConfirmationPopupView(
                    title: "Confirm assignment",
                    message: "This operation will remove the correspondent from 3 selected documents.",
                    isDestructive: true,
                    cancel: {},
                    confirm: {}
                )
            },
            as: .image(layout: .device(config: .iPhone12)),
            named: "destructive"
        )
    }
}
