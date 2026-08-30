import Components
import ComposableArchitecture
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
        // Pinned rather than left to its default: unpinned it is revealed by the first pull,
        // so a pull-to-refresh has to travel through it before the refresh starts.
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always))
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
