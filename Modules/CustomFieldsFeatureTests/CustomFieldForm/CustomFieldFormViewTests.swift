@testable import CustomFieldsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct CustomFieldFormViewTests {

    @Test
    func testSnapshot_create() async throws {
        assertSnapshot(
            of: CustomFieldFormView(
                store: Store(
                    initialState: .testValue(customField: nil),
                    reducer: {
                        CustomFieldFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Editing shows the data type as read-only text rather than a picker.
    @Test
    func testSnapshot_edit() async throws {
        assertSnapshot(
            of: CustomFieldFormView(
                store: Store(
                    initialState: .testValue(customField: .testValue(dataType: .string, name: "Reference")),
                    reducer: {
                        CustomFieldFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_select() async throws {
        assertSnapshot(
            of: CustomFieldFormView(
                store: Store(
                    initialState: .testValue(
                        customField: .testValue(
                            dataType: .select,
                            extraData: CustomFieldExtraData(selectOptions: [
                                CustomFieldSelectOption(id: "a", label: "Open"),
                                CustomFieldSelectOption(id: "b", label: "Closed")
                            ]),
                            name: "Status"
                        )
                    ),
                    reducer: {
                        CustomFieldFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // A freshly added option is blank, which is the only state that shows its placeholder.
    @Test
    func testSnapshot_selectWithBlankOption() async throws {
        var state = CustomFieldFormReducer.State(
            customField: .testValue(
                dataType: .select,
                extraData: CustomFieldExtraData(selectOptions: [
                    CustomFieldSelectOption(id: "a", label: "Open")
                ]),
                name: "Status"
            ),
            server: .testValue()
        )
        state.input.selectOptions.append(
            CustomFieldSelectOptionInput(id: UUID(0), label: "", serverId: nil)
        )

        assertSnapshot(
            of: CustomFieldFormView(
                store: Store(
                    initialState: state,
                    reducer: {
                        CustomFieldFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_monetary() async throws {
        assertSnapshot(
            of: CustomFieldFormView(
                store: Store(
                    initialState: .testValue(
                        customField: .testValue(
                            dataType: .monetary,
                            extraData: CustomFieldExtraData(defaultCurrency: "EUR"),
                            name: "Invoice total"
                        )
                    ),
                    reducer: {
                        CustomFieldFormReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
}
