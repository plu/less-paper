import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentTitleSuggestionsReducer.self)
struct DocumentTitleSuggestionsView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .suggestTitle,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                },
                right: {
                    Button {
                        send(.regenerateButtonTapped)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .sheetHeaderTapTarget()
                            .accessibilityLabel(.regenerate)
                    }
                    .disabled(store.isGenerating)
                }
            )
        } content: {
            content()
                .presentationDetents([.sheet])
        }
        // On the Sheet, not on the populated list: `suggestions` is empty when the sheet opens, so
        // an onAppear inside the list branch would never fire and nothing would ever generate.
        .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentTitleSuggestionsReducer>

    @ViewBuilder
    private func content() -> some View {
        if let error = store.error {
            EmptyListView(
                systemImage: "sparkles",
                title: .init(stringLiteral: error)
            ) {
                Button {
                    send(.retryButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.suggestions.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            suggestions()
        }
    }

    @ViewBuilder
    private func suggestions() -> some View {
        List {
            // Keyed by offset, not by value: a row's text fills in as the model streams, and its
            // position is what stays constant.
            ForEach(Array(store.suggestions.enumerated()), id: \.offset) { _, suggestion in
                Button {
                    send(.suggestionTapped(suggestion))
                } label: {
                    Text(suggestion)
                        .font(.body)
                        .foregroundStyle(Color.m3OnSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }

            if store.isGenerating {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.m3Surface)
                    .listRowSeparator(.hidden)
            }
        }
        .background(Color.m3Surface)
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
