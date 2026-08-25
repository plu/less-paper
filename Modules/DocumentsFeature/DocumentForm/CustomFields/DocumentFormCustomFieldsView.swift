import ApiInterface
import Components
import ComposableArchitecture
import CustomFieldsFeature
import SwiftUI

struct DocumentFormCustomFieldsView: View {

    var body: some View {
        if store.customFields.isEmpty {
            EmptyListView(
                systemImage: "list.bullet.rectangle",
                title: .noCustomFieldsDefined
            ) {
                Button {
                    store.send(.view(.createCustomFieldButtonTapped))
                } label: {
                    Label(.newCustomField, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.customFieldForm,
                    action: \.destination.customFieldForm
                )
            ) { store in
                CustomFieldFormView(store: store)
            }
            // Without this the empty state is laid out at its intrinsic width — a column narrow
            // enough to hyphenate the title and clip the button into a circle.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.input.customFields.isEmpty {
            EmptyListView(
                systemImage: "list.bullet.rectangle",
                title: .noCustomFieldsAttached
            ) {
                addMenu(isProminent: true)
            }
            // Same reason as the no-definitions state above: without this the empty state lays out
            // at its intrinsic width and clips the button.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: .x3) {
                ForEach($store.input.customFields) { $row in
                    if let field = store.customFields[id: row.id] {
                        DocumentFormCustomFieldRow(
                            field: field,
                            linkedDocuments: store.linkedCustomFieldDocuments,
                            onDocumentLinkTapped: {
                                store.send(.view(.documentLinkTapped(row.id)))
                            },
                            onRemove: {
                                store.send(.view(.removeCustomFieldTapped(row.id)))
                            },
                            value: $row.value
                        )
                    }
                }

                addMenu()
            }
            .frame(maxWidth: .infinity)
            // Only the rows can open the picker, so it hangs here rather than off the empty state.
            .sheet(
                item: $store.scope(
                    state: \.destination?.documentPicker,
                    action: \.destination.documentPicker
                )
            ) { store in
                DocumentPickerView(store: store)
                    .presentationDetents([.sheet])
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentFormReducer>

    private var unattached: [CustomField] {
        store.customFields.filter { store.input.customFields[id: $0.id] == nil }
    }

    // Prominent in an empty state, where it is the only call to action; subdued below a list of
    // rows, where it is subordinate to them.
    @ViewBuilder
    private func addMenu(isProminent: Bool = false) -> some View {
        Group {
            if isProminent {
                addMenuContent(systemImage: "plus.circle")
                    .buttonStyle(.primary())
            } else {
                addMenuContent(systemImage: "plus")
                    .buttonStyle(.secondary())
            }
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.customFieldForm,
                action: \.destination.customFieldForm
            )
        ) { store in
            CustomFieldFormView(store: store)
        }
    }

    @ViewBuilder
    private func addMenuContent(systemImage: String) -> some View {
        Menu {
            Button {
                store.send(.view(.createCustomFieldButtonTapped))
            } label: {
                Label(.newCustomField, systemImage: "plus")
            }

            if !unattached.isEmpty {
                Divider()

                ForEach(unattached) { field in
                    Button(field.name) {
                        store.send(.view(.addCustomFieldTapped(field.id)))
                    }
                }
            }
        } label: {
            Label(.addCustomField, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}
