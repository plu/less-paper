@testable import DocumentsFeature

import ApiInterface
import Components
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditTagsConfirmationViewTests {

    @Test
    func testSnapshot_add() async throws {
        assertSnapshot(
            of: popup(
                addTags: [
                    .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
                    .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000")
                ],
                removeTags: []
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "add"
        )
    }

    @Test
    func testSnapshot_remove() async throws {
        assertSnapshot(
            of: popup(
                addTags: [],
                removeTags: [
                    .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
                ]
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "remove"
        )
    }

    @Test
    func testSnapshot_addAndRemove() async throws {
        assertSnapshot(
            of: popup(
                addTags: [
                    .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
                    .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000")
                ],
                removeTags: [
                    .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
                ]
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "addAndRemove"
        )
    }

    @Test
    func testSnapshot_manyTags() async throws {
        assertSnapshot(
            of: popup(
                addTags: (1 ... 8).map {
                    .testValue(
                        color: "#A6CEE3",
                        id: .init(rawValue: $0),
                        name: "Tag number \($0)",
                        textColor: "#000000"
                    )
                },
                removeTags: []
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "manyTags"
        )
    }

    private func popup(
        addTags: [ApiInterface.Tag],
        removeTags: [ApiInterface.Tag]
    ) -> some View {
        ScrollView {
            ConfirmationPopupView(
                title: .confirmAssignment,
                cancel: {},
                confirm: {}
            ) {
                DocumentBulkEditTagsConfirmationView(
                    addTags: addTags,
                    documentCount: 5,
                    removeTags: removeTags
                )
            }
        }
    }
}
