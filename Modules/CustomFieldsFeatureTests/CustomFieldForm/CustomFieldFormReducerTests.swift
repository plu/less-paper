@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite
struct CustomFieldFormReducerTests {

    @Test
    func test_init_create_defaultsToString() async throws {
        let state = CustomFieldFormReducer.State(server: .testValue())

        #expect(state.customFieldId == nil)
        #expect(state.input.dataType == .string)
        #expect(state.input.name.value == "")
        #expect(state.isDataTypeLocked == false)
    }

    @Test
    func test_init_edit_locksDataTypeAndLoadsOptions() async throws {
        let state = CustomFieldFormReducer.State(
            customField: .testValue(
                dataType: .select,
                extraData: .init(selectOptions: [
                    .init(id: "a", label: "Open"),
                    .init(id: "b", label: "Closed")
                ]),
                name: "Status"
            ),
            server: .testValue()
        )

        #expect(state.isDataTypeLocked == true)
        #expect(state.input.dataType == .select)
        #expect(state.input.name.value == "Status")
        #expect(state.input.selectOptions.map(\.label) == ["Open", "Closed"])
        #expect(state.input.selectOptions.map(\.serverId) == ["a", "b"])
    }

    // Cancelling with a blank option used to send optionLabelChanged from the field's teardown,
    // after the parent had already cleared the destination. The reducer now ignores a label change
    // for an option that is gone - test_view_optionLabelChanged_forRemovedOption_isIgnored - and
    // this covers the dismissal itself, which nothing sent before.
    @Test
    func test_view_cancelButtonTapped_withABlankOption_dismisses() async throws {
        var isDismissed = false
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(1), label: "Open", serverId: "a"),
            CustomFieldSelectOptionInput(id: UUID(2), label: "", serverId: nil)
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.cancelButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_closeButtonTapped_dismisses() async throws {
        var isDismissed = false

        let store = TestStore(initialState: CustomFieldFormReducer.State(server: .testValue())) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_addOptionButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldFormReducer.State(server: .testValue())) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.view(.addOptionButtonTapped)) {
            $0.input.selectOptions = [
                CustomFieldSelectOptionInput(id: UUID(0), label: "", serverId: nil)
            ]
            $0.input.focusedOptionId = UUID(0)
        }
    }

    // Focus moves to the row that was just added, so typing lands there without a tap.
    @Test
    func test_view_addOptionButtonTapped_focusesTheNewOption() async throws {
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(9), label: "Open", serverId: "a")
        ]
        state.input.focusedOptionId = UUID(9)

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.view(.addOptionButtonTapped)) {
            $0.input.selectOptions.append(
                CustomFieldSelectOptionInput(id: UUID(0), label: "", serverId: nil)
            )
            $0.input.focusedOptionId = UUID(0)
        }
    }

    // The write a disappearing field delivers after its row is gone must not resurrect it.
    @Test
    func test_view_optionLabelChanged_forRemovedOption_isIgnored() async throws {
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(1), label: "Open", serverId: "a")
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        }

        await store.send(.view(.optionLabelChanged(id: UUID(99), label: "Ghost")))
        #expect(store.state.input.selectOptions.map(\.label) == ["Open"])
    }

    @Test
    func test_view_deleteOptionButtonTapped_clearsFocusWhenItHeldIt() async throws {
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(1), label: "", serverId: nil)
        ]
        state.input.focusedOptionId = UUID(1)

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        }

        await store.send(.view(.deleteOptionButtonTapped(id: UUID(1)))) {
            $0.input.selectOptions = []
            $0.input.focusedOptionId = nil
        }
    }

    @Test
    func test_view_deleteOptionButtonTapped() async throws {
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(0), label: "Open", serverId: "a"),
            CustomFieldSelectOptionInput(id: UUID(1), label: "Closed", serverId: "b")
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        }

        await store.send(.view(.deleteOptionButtonTapped(id: UUID(0)))) {
            $0.input.selectOptions = [
                CustomFieldSelectOptionInput(id: UUID(1), label: "Closed", serverId: "b")
            ]
        }
    }

    @Test
    func test_view_saveButtonTapped_create_success() async throws {
        let saved = LockIsolated<(CustomField.Id?, SaveCustomFieldInput)?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.name.value = "Reference"

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { id, input, _ in
                saved.setValue((id, input))
                return .testValue(id: 9, name: "Reference")
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.customFieldSaved, .testValue(id: 9, name: "Reference"))
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(saved.value?.0 == nil)
        #expect(saved.value?.1.name == "Reference")
        #expect(saved.value?.1.dataType == .string)
        #expect(saved.value?.1.extraData == nil)
    }

    // A select field must send its options; a plain field must send no extra_data at all.
    @Test
    func test_view_saveButtonTapped_select_sendsOptions() async throws {
        let saved = LockIsolated<SaveCustomFieldInput?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.dataType = .select
        state.input.name.value = "Status"
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(0), label: "Open", serverId: "a"),
            CustomFieldSelectOptionInput(id: UUID(1), label: "", serverId: nil)
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, input, _ in
                saved.setValue(input)
                return .testValue()
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.delegate)

        // The blank option the user added but never filled in is dropped rather than sent.
        #expect(saved.value?.extraData?.selectOptions?.map(\.label) == ["Open"])
        #expect(saved.value?.extraData?.selectOptions?.map(\.id) == ["a"])
    }

    @Test
    func test_view_saveButtonTapped_monetary_sendsCurrency() async throws {
        let saved = LockIsolated<SaveCustomFieldInput?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.dataType = .monetary
        state.input.defaultCurrency.value = "EUR"
        state.input.name.value = "Invoice total"

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, input, _ in
                saved.setValue(input)
                return .testValue()
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.delegate)

        #expect(saved.value?.extraData?.defaultCurrency == "EUR")
        #expect(saved.value?.extraData?.selectOptions == nil)
    }

    @Test
    func test_error_appliesFieldErrors() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: CustomFieldFormReducer.State(server: .testValue())) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, _, _ in
                throw ApiError.testValue(fieldErrors: ["name": ["This field must be unique."]])
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.input.name.error = "This field must be unique."
        }
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Some fields have errors")])
    }
}
