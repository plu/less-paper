import Components
import ComposableArchitecture
import DesignTokens
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
        // Left to its default so the field stays out of the way until pulled down. That costs
        // something real and known: the first pull of a pull-to-refresh travels through the field
        // before the refresh engages. These screens were pinned for exactly that reason and
        // deliberately unpinned again — a row of every screen spent on a control most visits never
        // use was the worse trade.
        .searchable(text: $store.searchText)
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
            if store.canCreate {
                Button(action: {
                    send(.createCorrespondentButtonTapped)
                }) {
                    Label(.createCorrespondent, systemImage: "plus")
                }
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
                    // No call to action for someone who cannot create correspondents: there is
                    // nothing there, and they cannot change that. Saying why would explain a
                    // boundary this app is not the one enforcing.
                    if store.canCreate {
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
