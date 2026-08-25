import ApiInterface
import Components
import ComposableArchitecture
import IdentifiedCollections
import SwiftUI

@ViewAction(for: CustomFieldQueryAtomEditorReducer.self)
struct CustomFieldQueryAtomEditorView: View {

    @Bindable
    var store: StoreOf<CustomFieldQueryAtomEditorReducer>

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
        .task {
            await send(.onAppear).finish()
        }
        .sheet(
            item: $store.scope(state: \.documentPicker, action: \.documentPicker)
        ) { store in
            DocumentPickerView(store: store)
                .presentationDetents([.sheet])
        }
        .sheet(isPresented: isSelectingOptions) {
            CustomFieldQuerySelectOptionsView(
                field: field,
                onViewAction: { send($0) },
                selected: selectedOptionIds
            )
            .presentationDetents([.sheet])
        }
    }

    private var atom: CustomFieldQuery.Atom {
        store.atom
    }

    private var fields: IdentifiedArrayOf<CustomField> {
        store.fields
    }

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    private var isSelectingOptions: Binding<Bool> {
        Binding(
            get: { store.isSelectingOptions },
            set: { isPresented in
                guard !isPresented else {
                    return
                }
                send(.optionsDismissed)
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
        store.selectedOptionIds
    }

    private var field: CustomField? {
        store.field
    }

    @ViewBuilder
    private func fieldPicker() -> some View {
        Field(.customField) {
            HStack {
                Picker("", selection: Binding(
                    get: { atom.field },
                    set: { send(.fieldChanged($0)) }
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
                    set: { send(.operatorChanged($0)) }
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
            // A documentlink field has no select options; its array holds document ids.
            switch field?.dataType {
            case .documentLink:
                documentLinkValue()
            default:
                selectOptions()
            }
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
                    set: { send(.valueChanged(.bool($0))) }
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
                set: { send(.valueChanged(.number(Double($0) ?? 0))) }
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
                        set: { send(.valueChanged(.string($0))) }
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
                    set: { send(.valueChanged(.string($0))) }
                ))
                .keyboardType(field?.dataType == .date ? .numbersAndPunctuation : .default)
                .textFieldStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func documentLinkValue() -> some View {
        Field(.value) {
            HStack(spacing: .x3) {
                if store.linkedDocumentIds.isEmpty {
                    Text(.any).capsule()
                    Spacer()
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: .x3) {
                            ForEach(store.linkedDocumentIds, id: \.self) { id in
                                Text(store.linkedDocuments[id: id]?.title ?? "#\(id.rawValue)")
                                    .capsule()
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .contentShape(.capsule)
        .onTapGesture {
            send(.documentPickerTapped)
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
            send(.optionsTapped)
        }
    }

    private var selectedLabels: [String] {
        (field?.extraData?.selectOptions ?? [])
            .filter { selectedOptionIds.contains($0.id ?? "") }
            .map(\.label)
    }
}
