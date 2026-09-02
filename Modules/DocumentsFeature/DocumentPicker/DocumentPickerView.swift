import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentPickerReducer.self)
struct DocumentPickerView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: .documents, left: closeButton)
        } content: {
            list()
        }
        .task {
            await send(.onAppear).finish()
        }
    }

    @Bindable
    var store: StoreOf<DocumentPickerReducer>

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        Searchable {
            List(store.rows) { document in
                row(document)
            }
            .background(Color.m3Surface)
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .navigationBarHidden(true)
            .overlay(emptyListView())
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
        }
    }

    @ViewBuilder
    private func row(_ document: Document) -> some View {
        Button {
            // Animated because selecting a row moves it: selected documents pin above the
            // results, so a tap reorders the list as well as ticking the row.
            send(.documentTapped(document.id), animation: .snappy)
        } label: {
            HStack(spacing: .x4) {
                Image(systemName: store.selection[id: document.id] != nil ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.m3Outline)
                VStack(alignment: .leading, spacing: .x1) {
                    Text(document.title)
                        .font(.body)
                        .foregroundStyle(Color.m3OnSurface)
                    Text(document.created, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(Color.m3Outline)
                }
            }
        }
        .foregroundStyle(Color.m3OnSurface)
        .id(document.id)
        .listRowBackground(Color.m3Surface)
        .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.rows.isEmpty, !store.isLoading {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }
}
