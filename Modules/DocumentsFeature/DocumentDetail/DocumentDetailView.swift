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
                    .ignoresSafeArea()
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
        .toolbar {
            Menu {
                if let url = store.downloadResult?.value?.url {
                    Button {
                        send(.previewButtonTapped)
                    } label: {
                        Label(.previewDocument, systemImage: "eye")
                    }

                    ShareLink(item: url) {
                        Label(.shareDocument, systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
            }

            Button(action: {
                send(.editDocumentButtonTapped)
            }) {
                Label(.editDocument, systemImage: "square.and.pencil")
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentDetailReducer>

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
