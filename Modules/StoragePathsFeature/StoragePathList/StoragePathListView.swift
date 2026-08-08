import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: StoragePathListReducer.self)
public struct StoragePathListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.storagePaths, action: \.storagePaths))) { store in
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
            Button(action: {
                send(.createStoragePathButtonTapped)
            }) {
                Label(.createStoragePath, systemImage: "plus")
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
