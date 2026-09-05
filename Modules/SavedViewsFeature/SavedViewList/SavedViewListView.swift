import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: SavedViewListReducer.self)
public struct SavedViewListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleSavedViews, action: \.savedViews))) { store in
                SavedViewRowView(store: store)
            }
        }
        .overlay(emptyListView())
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
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
            if store.permissions.can(.addSavedView) {
                Button(action: {
                    send(.createSavedViewButtonTapped)
                }) {
                    Label(.createSavedView, systemImage: "plus")
                }
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
                    // No call to action for someone who cannot create saved views: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.permissions.can(.addSavedView) {
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
