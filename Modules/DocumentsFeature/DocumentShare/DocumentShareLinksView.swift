import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentShareLinksReducer.self)
struct DocumentShareLinksView: View {

    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: .shareLinks, left: leftHeader)
        } content: {
            VStack(spacing: .x0) {
                List {
                    linkRows()
                }
                .scrollContentBackground(.hidden)
                .overlay(stateOverlay())

                form()
                    .padding(.x4)
            }
            .background(Color.m3SurfaceContainerLowest)
        } bottom: {
            Button {
                send(.createButtonTapped)
            } label: {
                Text(.createLink)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isCreating))
        }
        .presentationDetents([.sheet])
        .sheet(item: $store.shareItem) { item in
            ShareSheet(url: item.url)
        }
        .task { await send(.onAppear).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentShareLinksReducer>

    @Dependency(\.date.now)
    private var now

    @ViewBuilder
    private func errorView(error: String) -> some View {
        EmptyListView(
            systemImage: "exclamationmark.triangle",
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
        // The card paints its background outside its own bounds.
        .padding(.x5)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func form() -> some View {
        VStack(spacing: .x3) {
            AdaptiveStack(horizontalSpacing: .x3) {
                Text(.shareLinkExpires)
                    .accessibilityHidden(true)
                Spacer(minLength: .x0)
                Picker(selection: $store.expiry) {
                    ForEach(DocumentShareLinksExpiry.allCases) { expiry in
                        Text(expiry.localized).tag(expiry)
                    }
                } label: {
                    Text(.shareLinkExpires)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if store.hasArchiveVersion {
                Toggle(isOn: $store.shareArchiveVersion) {
                    Text(.shareArchivedVersion)
                }
                .tint(Color.m3Primary)
            }
        }
        .disabled(store.isCreating)
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func linkRows() -> some View {
        ForEach(store.links ?? []) { link in
            DocumentShareLinkRow(
                link: link,
                now: now,
                onDelete: store.canDelete
                    ? { send(.deleteButtonTapped(link.id)) }
                    : nil,
                onShare: { send(.shareButtonTapped(link.id)) },
                onTap: { send(.rowTapped(link.id)) },
                server: store.server
            )
        }
    }

    // Decided by `links` first: a create that succeeds while the list was refused leaves the error
    // set, and the list it produced must win over it.
    @ViewBuilder
    private func stateOverlay() -> some View {
        if let links = store.links {
            if links.isEmpty {
                EmptyListView(systemImage: "link", title: .noShareLinksYet)
            }
        } else if store.isLoading {
            ProgressView()
                .controlSize(.large)
        } else if let loadError = store.loadError {
            errorView(error: loadError)
        }
    }
}
