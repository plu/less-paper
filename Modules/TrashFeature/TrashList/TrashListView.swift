import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: TrashListReducer.self)
public struct TrashListView: View {

    public var body: some View {
        // The list is always there, with the empty state over it rather than instead of it. A
        // ContentUnavailableView on its own does not scroll, so pull to refresh - the only way back
        // from an empty trash to a full one - would be unavailable exactly when it is wanted.
        List {
            ForEach(store.visibleDocuments) { document in
                TrashRowView(
                    document: document,
                    isWorking: store.isWorkingOn.contains(document.id),
                    deleteForever: { send(.deleteForeverButtonTapped(document.id)) },
                    restore: { send(.restoreButtonTapped(document.id)) }
                )
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.trash)
        .overlay(emptyView())
        .refreshable { await send(.onRefresh).finish() }
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    send(.emptyTrashButtonTapped)
                } label: {
                    Label(.trashEmptyAll, systemImage: "trash.slash")
                }
                .disabled(store.documents.isEmpty)
            }
        }
    }

    public init(store: StoreOf<TrashListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<TrashListReducer>

    @ViewBuilder
    private func emptyView() -> some View {
        if store.documents.isEmpty, store.isLoaded {
            ContentUnavailableView {
                EmptyListView(systemImage: "trash", title: .trashEmpty) {
                    Text(.trashEmptyDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.m3OnSurface)
                        .multilineTextAlignment(.center)
                }
            }
            // Without this the overlay swallows the scroll, and pull to refresh stops working the
            // moment the trash is empty.
            .allowsHitTesting(false)
        }
    }
}
