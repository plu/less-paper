import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: CustomFieldListReducer.self)
public struct CustomFieldListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleCustomFields, action: \.customFields))) { store in
                CustomFieldRowView(store: store)
            }
        }
        .overlay(emptyListView())
        // Left to its default so the field stays out of the way until pulled down. That costs
        // something real and known: the first pull of a pull-to-refresh travels through the field
        // before the refresh engages. These screens were pinned for exactly that reason and
        // deliberately unpinned again — a row of every screen spent on a control most visits never
        // use was the worse trade.
        .searchable(text: $store.searchText)
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.customFields)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.customFieldForm, action: \.destination.customFieldForm)
        ) { store in
            CustomFieldFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            if store.canCreate {
                Button(action: {
                    send(.createCustomFieldButtonTapped)
                }) {
                    Label(.createCustomField, systemImage: "plus")
                }
            }
        }
    }

    public init(store: StoreOf<CustomFieldListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<CustomFieldListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.customFields.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "list.bullet.rectangle",
                    title: .noCustomFieldsFound
                ) {
                    // No call to action for someone who cannot create custom fields: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.canCreate {
                        Button {
                            send(.createCustomFieldButtonTapped)
                        } label: {
                            Label(.createCustomField, systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary())
                    }
                }
            }
        }
    }
}

#Preview {
    CustomFieldListView(
        store: Store(
            initialState: .testValue(customFields: .previewValue),
            reducer: {
                CustomFieldListReducer()
            }
        )
    )
}
