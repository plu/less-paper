import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import QuickLook
import SwiftUI

@ViewAction(for: DocumentDetailReducer.self)
public struct DocumentDetailView: View {
    public var body: some View {
        ZStack {
            switch store.downloadResult {
            case let .success(data, _):
                PDFKitView(data: data)
                    // Edge to edge on iPhone, where the view is the window. In a split view column
                    // it is not: ignoring the safe area there lets the view extend past the column,
                    // so the page is fitted to something wider than what is on screen and the
                    // reader sees a zoomed slice of it.
                    .ignoresSafeArea(edges: horizontalSizeClass == .compact ? .all : [])
            case let .failure(error):
                errorView(error: error)
            case .none:
                ProgressView()
                    .controlSize(.large)
                    .onAppear { send(.onAppear) }
            }
        }
        // Stated rather than inherited. `.automatic` adopts the previous navigation item's mode,
        // which is inline from either document list - but opening a document from the file tasks
        // sheet dismisses that sheet in the same mutation that pushes this view, and the mode
        // resolves against a bar that has not settled, so the title arrives large.
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(store.document.title)
        .quickLookPreview($store.quickLookPreview)
        .sheet(
            item: $store.scope(state: \.destination?.documentSheet, action: \.destination.documentSheet)
        ) { store in
            DocumentSheetView(store: store)
                .presentationDetents([.large])
        }
        .toolbar {
            // Not disabled while the download is in flight: only Preview needs the PDF, so the
            // menu still carries Share and Open before one has arrived.
            Menu {
                // The same three groups as the row's menu: the actions that run straight away, the
                // two submenus, and Delete a deliberate reach from the rest.
                //
                // Edit repeats the toolbar button beside this menu so the two menus read the same;
                // a snapshot is read-only, so neither offers it there.
                if store.isEditable {
                    Button {
                        send(.editDocumentButtonTapped)
                    } label: {
                        Label(.edit, systemImage: "square.and.pencil")
                    }
                }

                if store.downloadedURL != nil {
                    Button {
                        send(.previewButtonTapped)
                    } label: {
                        Label(.preview, systemImage: "eye")
                    }
                }

                // Last in its group rather than sorted in, for the same reason as the row's menu:
                // the label changes with state, so ordering it by its initial would move it under
                // the user's thumb as they used it.
                //
                // Saving offline means SaveOfflineDocumentUseCase's own reads run too, and on a
                // snapshot those are pinned to the record already on disk, not to this document —
                // adding one from here would only fail. Removing stays offered: removal
                // touches none of those reads.
                if !store.isOfflineSnapshot || store.isSavedOffline {
                    Button {
                        send(.saveOfflineButtonTapped)
                    } label: {
                        Label(
                            store.isSavedOffline ? .removeFromOffline : .saveOffline,
                            systemImage: store.isSavedOffline ? "arrow.down.circle.fill" : "arrow.down.circle"
                        )
                    }
                    .disabled(store.isTogglingOffline)
                }

                Divider()

                openMenu()

                shareMenu()

                if !store.isOfflineSnapshot, store.canDelete {
                    Divider()

                    Button(role: .destructive) {
                        send(.deleteButtonTapped)
                    } label: {
                        Label(.delete, systemImage: "trash")
                    }
                }
            } label: {
                // The menu dismisses on selection, so a spinner inside it would never be seen.
                // The toolbar item itself carries the wait instead.
                if store.isTogglingOffline {
                    ProgressView()
                } else {
                    Label(.moreActions, systemImage: "ellipsis.circle")
                }
            }

            // A shortcut to Open > Details, the section edited most. A snapshot is read-only, so it
            // is not offered there at all.
            if store.isEditable {
                Button(action: {
                    send(.editDocumentButtonTapped)
                }) {
                    Label(.edit, systemImage: "square.and.pencil")
                }
            }
        }
    }

    public init(store: StoreOf<DocumentDetailReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<DocumentDetailReducer>

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @ViewBuilder
    private func openMenu() -> some View {
        DocumentOpenMenu(
            sections: DocumentSheetSection.visible(
                isEditable: store.isEditable,
                canViewHistory: store.canViewHistory,
                canViewNotes: store.canViewNotes
            )
        ) { send(.openButtonTapped($0)) }
    }

    @ViewBuilder
    private func shareMenu() -> some View {
        DocumentShareMenu(documentId: store.document.id, server: store.server) {
            // Only once the file is here: detail has it downloaded already, so this shares it
            // directly rather than asking for it again.
            if let url = store.downloadedURL {
                ShareLink(item: url) {
                    Label(.document, systemImage: "doc")
                }
            }
        }
    }

    @ViewBuilder
    private func errorView(error: String) -> some View {
        EmptyListView(
            systemImage: "square.and.arrow.down.badge.xmark",
            title: .init(stringLiteral: error)
        ) {
            Button {
                send(.retryDownloadButtonTapped)
            } label: {
                Text(.retry)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
        }
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(
            store: Store(
                initialState: DocumentDetailReducer.State.testValue(
                    downloadResult: .testValue()
                ),
                reducer: {
                    DocumentDetailReducer()
                }
            )
        )
    }
}
