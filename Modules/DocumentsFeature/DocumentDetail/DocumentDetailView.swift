import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import QuickLook
import SwiftUI

@ViewAction(for: DocumentDetailReducer.self)
struct DocumentDetailView: View {
    var body: some View {
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
        .navigationTitle(store.document.title)
        .quickLookPreview($store.quickLookPreview)
        .sheet(
            item: $store.scope(state: \.destination?.documentForm, action: \.destination.documentForm)
        ) { store in
            DocumentFormView(store: store)
                .presentationDetents([.large])
        }
        .sheet(
            item: $store.scope(state: \.destination?.documentViewer, action: \.destination.documentViewer)
        ) { store in
            DocumentViewerView(store: store)
                .presentationDetents([.large])
        }
        .toolbar {
            // Not disabled while the download is in flight: the viewer needs no PDF, so the menu
            // always has that submenu even before Preview and Share appear.
            Menu {
                if let url = store.downloadedURL {
                    Button {
                        send(.previewButtonTapped)
                    } label: {
                        Label(.preview, systemImage: "eye")
                    }

                    ShareLink(item: url) {
                        Label(.share, systemImage: "square.and.arrow.up")
                    }

                    viewerMenu()
                } else {
                    viewerMenu()
                }

                // Outside the download branch: a link to the document is worth sharing whether or
                // not its file has come down yet.
                if let url = DeepLink.appURL(server: store.server, route: .documentDetail(store.document.id)) {
                    ShareLink(item: url) {
                        Label(.shareAppLink, systemImage: "candybarphone")
                    }
                }

                if let url = DeepLink.webURL(server: store.server, route: .documentDetail(store.document.id)) {
                    ShareLink(item: url) {
                        Label(.shareWebLink, systemImage: "globe")
                    }
                }
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
            }

            Button(action: {
                send(.editDocumentButtonTapped)
            }) {
                Label(.edit, systemImage: "square.and.pencil")
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentDetailReducer>

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @ViewBuilder
    private func viewerMenu() -> some View {
        DocumentViewerMenu { send(.viewButtonTapped($0)) }
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
                Text(.retryDownload)
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
