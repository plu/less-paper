import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentBulkEditTitleReducer.self)
struct DocumentBulkEditTitleView: View {

    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .editTitle,
                left: leftHeader,
                right: rightHeader
            )
        } content: {
            VStack(spacing: .x4) {
                TitleField(text: $store.template)
                    .disabled(store.isSaving)
                    .padding(.horizontal, .x4)
                    .padding(.top, .x4)
                list()
            }
        } bottom: {
            buttons()
        }
        .presentationDetents([.sheet])
        .task { await send(.onAppear).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentBulkEditTitleReducer>

    @ViewBuilder
    private func buttons() -> some View {
        VStack(spacing: .x3) {
            if store.isSaving {
                ProgressView(value: store.progress, total: 1.0)
                    .tint(Color.m3Primary)
            }

            AdaptiveStack {
                Button {
                    send(.resetButtonTapped)
                } label: {
                    Text(.reset)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
                .disabled(store.template.isEmpty)

                Button {
                    send(.applyButtonTapped)
                } label: {
                    Text(.apply)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary(isLoading: $store.isSaving))
                .disabled(!store.isEdited || store.isLoading)
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
        List(store.previews) { preview in
            DocumentBulkEditTitlePreviewRow(preview: preview)
                .id(preview.id)
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x2, leading: .x4, bottom: .x2, trailing: .x4))
                .listRowSeparator(.hidden)
        }
        .background(Color.m3Surface)
        .disabled(store.isSaving)
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .overlay(loadingView())
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func rightHeader() -> some View {
        Menu {
            ForEach(DocumentBulkEditTitlePlaceholder.allCases) { placeholder in
                Button {
                    send(.placeholderTapped(placeholder))
                } label: {
                    Text(placeholder.localized)
                }
            }
        } label: {
            Image(systemName: "curlybraces")
                .sheetHeaderTapTarget()
                .accessibilityLabel(.placeholders)
        }
        .disabled(store.isSaving)
    }
}
