import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: PdfPasswordListReducer.self)
public struct PdfPasswordListView: View {

    @Bindable public var store: StoreOf<PdfPasswordListReducer>

    public init(store: StoreOf<PdfPasswordListReducer>) {
        self.store = store
    }

    public var body: some View {
        // Attached only when there is something to search. The field sits above the list and hides
        // by scrolling out of view, so over an empty list it has nowhere to go and simply stays on
        // screen - and a search field above nothing cannot do anything anyway.
        //
        // The searchText half is not belt and braces: a query matching nothing empties the list,
        // and without it the field would vanish mid-search, taking the query with it.
        if !store.visiblePdfPasswords.isEmpty || !store.searchText.isEmpty {
            content.searchable(text: $store.searchText)
        } else {
            content
        }
    }

    private var content: some View {
        List {
            ForEach(
                store.scope(state: \.visiblePdfPasswords, action: \.pdfPasswords),
                id: \.state.id
            ) { rowStore in
                PdfPasswordRowView(store: rowStore)
                    .listRowBackground(Color.m3SurfaceContainer)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.m3Surface)
        .navigationTitle(Text(.pdfPasswords))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await send(.onRefresh).finish() }
        .task { await send(.onAppear).finish() }
        .overlay {
            if store.isLoaded, store.pdfPasswords.isEmpty {
                ContentUnavailableView {
                    EmptyListView(
                        systemImage: "key",
                        title: .pdfPasswordsEmpty
                    )
                }
            }
        }
    }
}
