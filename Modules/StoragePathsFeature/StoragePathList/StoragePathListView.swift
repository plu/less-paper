import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: StoragePathListReducer.self)
public struct StoragePathListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleStoragePaths.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleStoragePaths, action: \.storagePaths))) { store in
                StoragePathRowView(store: store)
            }
        }
        .overlay(emptyListView())
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.storagePaths)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.storagePathForm, action: \.destination.storagePathForm)
        ) { store in
            StoragePathFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            if store.canCreate {
                Button(action: {
                    send(.createStoragePathButtonTapped)
                }) {
                    Label(.createStoragePath, systemImage: "plus")
                }
            }
        }
    }

    public init(store: StoreOf<StoragePathListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<StoragePathListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.storagePaths.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "folder",
                    title: .noStoragePathsFound
                ) {
                    // No call to action for someone who cannot create storage paths: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.canCreate {
                        Button {
                            send(.createStoragePathButtonTapped)
                        } label: {
                            Label(.createStoragePath, systemImage: "plus.circle")
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
    StoragePathListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                StoragePathListReducer()
            }
        )
    )
}
