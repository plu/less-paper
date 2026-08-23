import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: CustomFieldFormReducer.self)
public struct CustomFieldFormView: View {

    public var body: some View {
        Sheet {
            SheetHeader(
                title: store.customFieldId == nil ? .createCustomField : .editCustomField,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                }
            )
        } content: {
            VStack(spacing: .x4) {
                nameField()
                dataTypeField()

                switch store.input.dataType {
                case .monetary:
                    defaultCurrencyField()
                case .select:
                    selectOptionsSection()
                case .boolean, .date, .documentLink, .float, .integer, .longText, .string, .unknown, .url:
                    EmptyView()
                }
            }
        } bottom: {
            buttons()
        }
    }

    public init(store: StoreOf<CustomFieldFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<CustomFieldFormReducer>

    @FocusState
    private var focusedOption: UUID?

    private func optionLabelBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.input.selectOptions[id: id]?.label ?? "" },
            set: { newValue in
                // A text field commits its current value as it tears down, which on dismiss lands
                // after the parent has cleared the destination — TCA then warns about a
                // presentation action with no state behind it. That final write never changes
                // anything, so comparing first keeps the action from being sent at all.
                guard store.input.selectOptions[id: id]?.label != newValue else {
                    return
                }
                send(.optionLabelChanged(id: id, label: newValue))
            }
        )
    }

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.cancelButtonTapped)
            } label: {
                Text(.cancel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .frame(maxWidth: .infinity)

            Button {
                send(.saveButtonTapped)
            } label: {
                Text(.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
        }
    }

    @ViewBuilder
    private func dataTypeField() -> some View {
        if store.isDataTypeLocked {
            Field(.dataType) {
                HStack {
                    // Same colour as an editable value, not `m3Outline`: this is the field's real
                    // type, and grey text in an empty-looking capsule reads as a placeholder
                    // prompting for input. The dimmed fill is what says "not editable".
                    Text(store.input.dataType.description)
                        .foregroundStyle(Color.m3OnSurface)
                    Spacer()
                }
            }
            .readOnly()
        } else {
            MenuField(
                title: .dataType,
                value: $store.input.dataType
            )
        }
    }

    @ViewBuilder
    private func defaultCurrencyField() -> some View {
        Field(.defaultCurrency) {
            TextField(String(localized: .defaultCurrency), text: $store.input.defaultCurrency.value)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
        }
        .state($store.input.defaultCurrency)
    }

    @ViewBuilder
    private func nameField() -> some View {
        Field(.name) {
            TextField(String(localized: .name), text: $store.input.name.value)
                .textFieldStyle(.plain)
        }
        .state($store.input.name)
    }

    @ViewBuilder
    private func selectOptionsSection() -> some View {
        // Grouped the way `PermissionsFormView` groups Change and View: a semibold heading over a
        // filled container, so the rows read as one list rather than as loose fields.
        VStack(alignment: .leading, spacing: .x0) {
            Text(.selectOptions)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: .x4) {
                // Iterating values and addressing each row by id, never `ForEach($binding)`: those
                // element bindings are index-based, so a row's field writing back as it disappeared
                // read off the end of the shrunken array and crashed.
                ForEach(store.input.selectOptions) { option in
                    HStack {
                        Field {
                            TextField(String(localized: .option), text: optionLabelBinding(option.id))
                                .textFieldStyle(.plain)
                                .focused($focusedOption, equals: option.id)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { focusedOption = option.id }

                        Button {
                            send(.deleteOptionButtonTapped(id: option.id), animation: .default)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.m3Error)
                        }
                        .accessibilityLabel(.deleteOption)
                    }
                }

                Button {
                    send(.addOptionButtonTapped, animation: .default)
                } label: {
                    Label(.addOption, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
        }
        .onChange(of: store.input.focusedOptionId) { _, newValue in
            focusedOption = newValue
        }
    }
}

#Preview {
    CustomFieldFormView(
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
    )
}
