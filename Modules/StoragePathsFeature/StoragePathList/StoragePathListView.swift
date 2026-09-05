import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: StoragePathListReducer.self)
public struct StoragePathListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleStoragePaths, action: \.storagePaths))) { store in
                StoragePathRowView(store: store)
            }
        }
        .overlay(emptyListView())
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
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
            if store.permissions.can(.addStoragePath) {
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
                    if store.permissions.can(.addStoragePath) {
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
