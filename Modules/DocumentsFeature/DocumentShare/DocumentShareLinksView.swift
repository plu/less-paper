import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentShareLinksReducer.self)
struct DocumentShareLinksView: View {

    var body: some View {
        Sheet {
            SheetHeader(title: .shareLinks, left: leftHeader)
        } content: {
            VStack(alignment: .leading, spacing: .x4) {
                linksSection()
                form()
            }
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
            systemImage: "link.badge.plus",
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

    // Decided by `links` first: a create that succeeds while the list was refused leaves the error
    // set, and the list it produced must win over it.
    @ViewBuilder
    private func linksSection() -> some View {
        if let links = store.links {
            if links.isEmpty {
                Text(.noShareLinksYet)
                    .font(.body)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .x4)
            } else {
                VStack(spacing: .x0) {
                    ForEach(links) { link in
                        DocumentShareLinkRow(
                            link: link,
                            now: now,
                            onCopy: { send(.copyButtonTapped(link.id)) },
                            onDelete: store.canDelete
                                ? { send(.deleteButtonTapped(link.id)) }
                                : nil,
                            server: store.server
                        )
                    }
                }
            }
        } else if store.isLoading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .x4)
        } else if let loadError = store.loadError {
            errorView(error: loadError)
        }
    }
}
