import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: TrashListReducer.self)
public struct TrashListView: View {

    public var body: some View {
        Group {
            if store.documents.isEmpty, store.isLoaded {
                ContentUnavailableView {
                    EmptyListView(systemImage: "trash", title: .trashEmpty) {
                        Text(.trashEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(Color.m3OnSurface)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                List {
                    ForEach(store.documents) { document in
                        TrashRowView(
                            document: document,
                            isWorking: store.isWorkingOn.contains(document.id),
                            deleteForever: { send(.deleteForeverButtonTapped(document.id)) },
                            restore: { send(.restoreButtonTapped(document.id)) }
                        )
                        .listRowBackground(Color.m3SurfaceContainer)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.trash)
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
}
