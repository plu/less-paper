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
            // Not disabled while the download is in flight: only Preview needs the PDF, so the
            // menu still carries Share and View before one has arrived.
            Menu {
                if store.downloadedURL != nil {
                    Button {
                        send(.previewButtonTapped)
                    } label: {
                        Label(.preview, systemImage: "eye")
                    }
                }

                shareMenu()

                viewerMenu()
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
