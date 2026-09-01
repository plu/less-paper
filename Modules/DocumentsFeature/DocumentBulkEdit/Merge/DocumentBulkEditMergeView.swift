import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentBulkEditMergeReducer.self)
struct DocumentBulkEditMergeView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .mergeDocuments,
                left: leftHeader
            )
        } content: {
            list()
        } bottom: {
            buttons()
        }
        .task { await send(.onAppear).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentBulkEditMergeReducer>

    @ViewBuilder
    private func buttons() -> some View {
        VStack(spacing: .x4) {
            Toggle(isOn: $store.deleteOriginals) {
                Text(.deleteOriginals)
            }
            .disabled(store.isSaving)
            .tint(Color.m3Primary)

            Button {
                send(.mergeButtonTapped)
            } label: {
                Text(.merge)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
            .disabled(!store.canMerge)
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        List {
            ForEach(store.documents) { document in
                Text(document.title)
                    .foregroundStyle(Color.m3OnSurface)
                    .listRowBackground(Color.m3Surface)
                    .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                    .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                send(.moved(source, destination))
            }
        }
        .background(Color.m3Surface)
        .environment(\.defaultMinListRowHeight, 0)
        // Forced active because the sheet has no Edit button: without it `onMove` never engages and
        // the rows cannot be dragged at all.
        .environment(\.editMode, .constant(.active))
        .listStyle(.plain)
        .overlay(loadingView())
        .presentationDetents([.sheet])
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }
}
