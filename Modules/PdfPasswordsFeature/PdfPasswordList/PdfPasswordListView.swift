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
                store.scope(state: \.pdfPasswords, action: \.pdfPasswords),
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
