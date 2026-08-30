import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: CorrespondentListReducer.self)
public struct CorrespondentListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleCorrespondents, action: \.correspondents))) { store in
                CorrespondentRowView(store: store)
            }
        }
        .overlay(emptyListView())
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.correspondents)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.correspondentForm, action: \.destination.correspondentForm)
        ) { store in
            CorrespondentFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            Button(action: {
                send(.createCorrespondentButtonTapped)
            }) {
                Label(.createCorrespondent, systemImage: "plus")
            }
        }
    }

    public init(store: StoreOf<CorrespondentListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<CorrespondentListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.correspondents.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "person",
                    title: .noCorrespondentsFound
                ) {
                    Button {
                        send(.createCorrespondentButtonTapped)
                    } label: {
                        Label(.createCorrespondent, systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary())
                }
            }
        }
    }
}

#Preview {
    CorrespondentListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                CorrespondentListReducer()
            }
        )
    )
}
