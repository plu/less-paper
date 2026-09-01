import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentBulkEditTagsReducer.self)
struct DocumentBulkEditTagsView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .editTags,
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
    var store: StoreOf<DocumentBulkEditTagsReducer>

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.resetButtonTapped)
            } label: {
                Text(.reset)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .disabled(!store.isEdited)

            Button {
                send(.applyButtonTapped)
            } label: {
                Text(.apply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
            .disabled(!store.isEdited)
        }
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.filteredValues.isEmpty, !store.isLoading {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
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
        Searchable {
            List(store.filteredValues) { value in
                Button {
                    send(.valueTapped(value))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: store.state.systemImage(for: value))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.m3Outline)
                        Text(value.description)
                            .capsule(
                                backgroundColor: Color(hex: value.color),
                                font: .body,
                                foregroundColor: Color(hex: value.textColor)
                            )
                        Spacer()
                        Text(String(store.documentCounts[value.id] ?? 0))
                            .font(.caption2)
                            .foregroundStyle(Color.m3OnSurface)
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
                .id(value.id)
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }
            .background(Color.m3Surface)
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .navigationBarHidden(true)
            .overlay(emptyListView())
            .overlay(loadingView())
            .presentationDetents([.sheet])
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }
}
