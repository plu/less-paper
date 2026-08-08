@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SingleSelectFieldTests {

    @Test
    func testSnapshot_selection() async throws {
        let model = SingleSelectFieldPreview.Model()
        model.selection = .init(description: "John")
        let previewValue = SingleSelectFieldPreview(model: model)

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
        let model = SingleSelectFieldPreview.Model()
        model.selection = nil
        let previewValue = SingleSelectFieldPreview(model: model)

        assertSnapshot(
            of: VStack {
                previewValue
                Spacer()
            },
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
