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
                    Text(.newCustomField)
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

                if store.input.customFields.isEmpty {
                    Text(.noCustomFieldsAttached)
                        .font(.subheadline)
                        .foregroundColor(.m3Outline)
                }

                addMenu()
            }
            .frame(maxWidth: .infinity)
        }
    }

    @Bindable
    var store: StoreOf<DocumentFormReducer>

    private var unattached: [CustomField] {
        store.customFields.filter { store.input.customFields[id: $0.id] == nil }
    }

    @ViewBuilder
    private func addMenu() -> some View {
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
            Label(.addCustomField, systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondary())
        .sheet(
            item: $store.scope(
                state: \.destination?.customFieldForm,
                action: \.destination.customFieldForm
            )
        ) { store in
            CustomFieldFormView(store: store)
        }
    }
}
