import ApiInterface
import Components
import IdentifiedCollections
import SwiftUI

// Not `@ViewAction`: the editor is presented from a sheet item rather than scoped to a child
// store, so it takes the parent's `send` and posts view actions through it.
struct CustomFieldQueryAtomEditorView: View {

    let editor: CustomFieldQueryCardsReducer.State.Editor

    let fields: IdentifiedArrayOf<CustomField>

    let onViewAction: (CustomFieldQueryCardsReducer.Action.View) -> Void

    var body: some View {
        Sheet {
            SheetHeader(title: .customFields, left: closeButton)
        } content: {
            VStack(spacing: .x3) {
                fieldPicker()
                operatorPicker()
                valueEditor()
            }
        }
        .sheet(isPresented: isSelectingOptions) {
            CustomFieldQuerySelectOptionsView(
                field: field,
                onViewAction: onViewAction,
                selected: selectedOptionIds
            )
            .presentationDetents([.sheet])
        }
    }

    private var atom: CustomFieldQuery.Atom {
        editor.atom
    }

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            onViewAction(.editorDismissed)
        }
    }

    private var isSelectingOptions: Binding<Bool> {
        Binding(
            get: { editor.isSelectingOptions },
            set: { isPresented in
                guard !isPresented else {
                    return
                }
                onViewAction(.editorOptionsDismissed)
            }
        )
    }

    private var selectedOptionId: String {
        guard case let .string(text) = atom.value else {
            return ""
        }
        return text
    }

    private var selectedOptionIds: Set<String> {
        Set(atom.value.arrayValue?.compactMap(\.stringValue) ?? [])
    }

    private var field: CustomField? {
        fields[id: atom.field]
    }

    @ViewBuilder
    private func fieldPicker() -> some View {
        Field(.customField) {
            HStack {
                Picker("", selection: Binding(
                    get: { atom.field },
                    set: { onViewAction(.editorFieldChanged($0)) }
                )) {
                    ForEach(fields) { field in
                        Text(field.name).tag(field.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.m3OnSurface)
                .offset(x: -12)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func operatorPicker() -> some View {
        Field(.customFieldQueryOperator) {
            HStack {
                Picker("", selection: Binding(
                    get: { atom.op },
                    set: { onViewAction(.editorOperatorChanged($0)) }
                )) {
                    ForEach(CustomFieldQueryOperator.operators(for: field?.dataType ?? .string)) { queryOperator in
                        Text(queryOperator.description).tag(queryOperator)
                    }
                }
                .pickerStyle(.menu)
                .tint(.m3OnSurface)
                .offset(x: -12)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func valueEditor() -> some View {
        switch atom.op.valueKind {
        case .array:
            selectOptions()
        case .boolean:
            booleanToggle()
        case .number:
            numberField()
        case .string:
            stringField()
        }
    }

    @ViewBuilder
    private func booleanToggle() -> some View {
        Field(.value) {
            HStack {
                Toggle(isOn: Binding(
                    get: {
                        guard case let .bool(flag) = atom.value else {
                            return false
                        }
                        return flag
                    },
                    set: { onViewAction(.editorValueChanged(.bool($0))) }
                )) {
                    Text(.value)
                }
                .labelsHidden()

                Spacer()
            }
        }
        .tint(Color.m3Primary)
    }

    @ViewBuilder
    private func numberField() -> some View {
        Field(.value) {
            TextField(String(localized: .value), text: Binding(
                get: {
                    guard case let .number(number) = atom.value else {
                        return ""
                    }
                    return number.rounded() == number ? String(Int(number)) : String(number)
                },
                set: { onViewAction(.editorValueChanged(.number(Double($0) ?? 0))) }
            ))
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)
        }
    }

    @ViewBuilder
    private func stringField() -> some View {
        if let options = field?.extraData?.selectOptions, !options.isEmpty {
            Field(.value) {
                HStack {
                    Picker("", selection: Binding(
                        get: {
                            guard case let .string(text) = atom.value else {
                                return ""
                            }
                            return text
                        },
                        set: { onViewAction(.editorValueChanged(.string($0))) }
                    )) {
                        ForEach(options, id: \.label) { option in
                            Text(option.label).tag(option.id ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.m3OnSurface)
                    .offset(x: -12)

                    Spacer()
                }
            }
        } else {
            Field(.value) {
                TextField(String(localized: .value), text: Binding(
                    get: {
                        guard case let .string(text) = atom.value else {
                            return ""
                        }
                        return text
                    },
                    set: { onViewAction(.editorValueChanged(.string($0))) }
                ))
                .keyboardType(field?.dataType == .date ? .numbersAndPunctuation : .default)
                .textFieldStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func selectOptions() -> some View {
        Field(.value) {
            HStack(spacing: .x3) {
                if selectedOptionIds.isEmpty {
                    Text(.any).capsule()
                    Spacer()
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: .x3) {
                            ForEach(selectedLabels, id: \.self) { label in
                                Text(label).capsule()
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .contentShape(.capsule)
        .onTapGesture {
            onViewAction(.editorOptionsTapped)
        }
    }

    private var selectedLabels: [String] {
        (field?.extraData?.selectOptions ?? [])
            .filter { selectedOptionIds.contains($0.id ?? "") }
            .map(\.label)
    }
}
