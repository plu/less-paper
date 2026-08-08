@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct MultiSelectOptionsTests {

    @Test
    func testSnapshot_selection() async throws {
        let model = MultiSelectFieldPreview.Model()
        model.selection = Set([
            model.options.first,
            model.options.last
        ].compactMap(\.self))

        assertSnapshot(
            of: MultiSelectOptions(
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select Options"
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        let model = MultiSelectFieldPreview.Model()
        model.selection = []

        assertSnapshot(
            of: MultiSelectOptions(
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select Options"
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_createButton() async throws {
        let model = MultiSelectFieldPreview.Model()
        model.selection = []

        assertSnapshot(
            of: MultiSelectOptions(
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select Options",
                onCreate: {}
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
