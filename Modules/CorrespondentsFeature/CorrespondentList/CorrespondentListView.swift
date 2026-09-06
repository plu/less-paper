import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: CorrespondentListReducer.self)
public struct CorrespondentListView: View {

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visibleCorrespondents.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(Array(store.scope(state: \.visibleCorrespondents, action: \.correspondents))) { store in
                CorrespondentRowView(store: store)
            }
        }
        .overlay(emptyListView())
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
