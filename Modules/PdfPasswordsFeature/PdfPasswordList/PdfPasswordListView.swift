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
        // Left to its default so the field stays out of the way until pulled down. That costs
        // something real and known: the first pull of a pull-to-refresh travels through the field
        // before the refresh engages. These screens were pinned for exactly that reason and
        // deliberately unpinned again — a row of every screen spent on a control most visits never
        // use was the worse trade.
        .searchable(text: $store.searchText)
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
