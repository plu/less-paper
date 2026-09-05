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
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
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
            if store.permissions.can(.addCustomField) {
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
                    if store.permissions.can(.addCustomField) {
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
