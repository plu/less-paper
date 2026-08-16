import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
struct DocumentListEmptyView: View {
    var body: some View {
        if store.documents.isEmpty && store.isLoaded {
            ContentUnavailableView {
                emptyListView()
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentListReducer>

    // The order is the logic. `isInboxWithoutInboxTags` has to be tested before the inbox is called
    // empty, or an inbox that can never hold anything is reported as an achievement; both inbox
    // cases have to be tested before `hasActiveFilter`, because the inbox filter is itself a tag
    // filter and would otherwise swallow them.
    @ViewBuilder
    private func emptyListView() -> some View {
        if let error = store.error {
            EmptyListView(
                systemImage: "exclamationmark.triangle",
                title: LocalizedStringResource(stringLiteral: error),
                content: reloadButton
            )
        } else if store.isInboxWithoutInboxTags {
            EmptyListView(
                systemImage: "tag.slash",
                title: .noInboxTagConfigured,
                content: reloadButton
            )
        } else if store.filter.isInbox {
            // No button: an empty inbox is the outcome the user wants, and offering a retry implies
            // something might be missing. Pull-to-refresh on the list still works.
            EmptyListView(
                systemImage: "checkmark.circle",
                title: .allCaughtUp
            )
        } else if store.hasActiveFilter {
            EmptyListView(
                systemImage: "magnifyingglass",
                title: .noMatchingDocuments,
                content: filterButton
            )
        } else {
            EmptyListView(
                systemImage: "tray",
                title: .noDocumentsFound,
                content: reloadButton
            )
        }
    }

    @ViewBuilder
    private func filterButton() -> some View {
        Button {
            send(.filterButtonTapped)
        } label: {
            Label(.filter, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
    }

    @ViewBuilder
    private func reloadButton() -> some View {
        Button {
            send(.reloadButtonTapped)
        } label: {
            Label(.reload, systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
    }
}
