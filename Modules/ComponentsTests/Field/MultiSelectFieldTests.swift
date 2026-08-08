@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct MultiSelectFieldTests {

    @Test
    func testSnapshot_selection() async throws {
        let model = MultiSelectFieldPreview.Model()
        model.selection = [
            .init(description: "John"),
            .init(description: "Rita")
        ]
        let previewValue = MultiSelectFieldPreview(model: model)

        assertSnapshot(
            of: VStack {
                previewValue
                Spacer()
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        let model = MultiSelectFieldPreview.Model()
        model.selection = []
        let previewValue = MultiSelectFieldPreview(model: model)

        assertSnapshot(
            of: VStack {
                previewValue
                Spacer()
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
