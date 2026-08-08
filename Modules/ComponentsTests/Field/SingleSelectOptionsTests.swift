@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct SingleSelectOptionsTests {

    @Test
    func testSnapshot_selection() async throws {
        let model = SingleSelectFieldPreview.Model()
        model.selection = model.options.first

        assertSnapshot(
            of: SingleSelectOptions(
                clearable: false,
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select an option"
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        let model = SingleSelectFieldPreview.Model()
        model.selection = nil

        assertSnapshot(
            of: SingleSelectOptions(
                clearable: false,
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select an option"
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_createButton() async throws {
        let model = SingleSelectFieldPreview.Model()
        model.selection = nil

        assertSnapshot(
            of: SingleSelectOptions(
                clearable: false,
                isPresented: .constant(true),
                options: model.options,
                selection: Binding(get: { model.selection }, set: { model.selection = $0 }),
                title: "Select an option",
                onCreate: {}
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
