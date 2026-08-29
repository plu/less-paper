import ApiInterface
import Components
import ComposableArchitecture
import DocumentsFeature
import SwiftUI

@ViewAction(for: FavoriteListReducer.self)
public struct FavoriteListView: View {

    // Its own NavigationStack rather than `Searchable`'s: the pushes are driven by the reducer's
    // StackState, and `Searchable` builds an unbound stack that a path binding cannot reach.
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                ForEach(store.scope(state: \.rows, action: \.rows)) { store in
                    FavoriteRowView(store: store)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.x3)
                }
            }
            .background(Color.m3SurfaceContainerLowest)
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(.favorites)
            .onDisappear { send(.onDisappear) }
            .overlay(emptyListView())
            .refreshable { await send(.onRefresh).finish() }
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
            .task { await send(.onAppear).finish() }
        } destination: { store in
            switch store.case {
            case let .documentDetail(store):
                DocumentDetailView(store: store)
            }
        }
    }

    public init(store: StoreOf<FavoriteListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<FavoriteListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.favorites.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "heart", title: .noFavorites) {
                    Text(.noFavoritesMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color.m3OnSurface)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

#Preview {
    FavoriteListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                FavoriteListReducer()
            }
        )
    )
}
