import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: CustomFieldListReducer.self)
public struct CustomFieldListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleCustomFields.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleCustomFields, action: \.customFields))) { store in
                CustomFieldRowView(store: store)
            }
        }
        .overlay(emptyListView())
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
