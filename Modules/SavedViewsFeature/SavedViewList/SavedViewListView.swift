import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: SavedViewListReducer.self)
public struct SavedViewListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.savedViews, action: \.savedViews))) { store in
                SavedViewRowView(store: store)
            }
        }
        .overlay(emptyListView())
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.savedViews)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.savedViewForm, action: \.destination.savedViewForm)
        ) { store in
            SavedViewFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            Button(action: {
                send(.createSavedViewButtonTapped)
            }) {
                Label(.createSavedView, systemImage: "plus")
            }
        }
    }

    public init(store: StoreOf<SavedViewListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SavedViewListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.savedViews.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "line.3.horizontal.decrease",
                    title: .noSavedViewsFound
                ) {
                    Button {
                        send(.createSavedViewButtonTapped)
                    } label: {
                        Label(.createSavedView, systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary())
                }
            }
        }
    }
}

#Preview {
    SavedViewListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                SavedViewListReducer()
            }
        )
    )
}
