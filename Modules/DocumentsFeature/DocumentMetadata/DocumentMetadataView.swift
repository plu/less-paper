import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentMetadataReducer.self)
struct DocumentMetadataView: View {

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentMetadataReducer>

    @ViewBuilder
    private func content() -> some View {
        if let loadError = store.loadError {
            EmptyListView(
                systemImage: "info.circle",
                title: .init(stringLiteral: loadError)
            ) {
                Button {
                    send(.retryLoadButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        } else if let metadata = store.metadata {
            if metadata.isEmpty {
                EmptyListView(
                    systemImage: "info.circle",
                    title: .noMetadataFound
                )
            } else {
                metadataSections(metadata: metadata)
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func metadataSections(metadata: DocumentMetadata) -> some View {
        VStack(alignment: .leading, spacing: .x4) {
            DocumentMetadataGroupView(
                rows: [
                    .init(title: .filename, value: metadata.originalFilename),
                    .init(title: .mediaFilename, value: metadata.mediaFilename),
                    .init(title: .mimeType, value: metadata.originalMimeType),
                    .init(title: .size, value: metadata.originalSize?.formattedFileSize),
                    .init(title: .checksum, value: metadata.originalChecksum, isMonospaced: true),
                    .init(title: .language, value: metadata.lang),
                ],
                title: .original
            )

            // Six of the fixtures have no archived copy at all, and the server answers with three
            // nulls rather than omitting them. An empty Archive card would be the wrong answer to
            // "is there one".
            if metadata.hasArchiveVersion {
                DocumentMetadataGroupView(
                    rows: [
                        .init(title: .mediaFilename, value: metadata.archiveMediaFilename),
                        .init(title: .size, value: metadata.archiveSize?.formattedFileSize),
                        .init(title: .checksum, value: metadata.archiveChecksum, isMonospaced: true),
                    ],
                    title: .archive
                )
            }

            Spacer(minLength: 0)
        }
        // Reading a checksum off a screen is not how anyone uses one.
        .textSelection(.enabled)
    }
}

private extension Int {

    var formattedFileSize: String {
        formatted(.byteCount(style: .file))
    }
}

#Preview {
    DocumentMetadataView(
        store: Store(
            initialState: DocumentMetadataReducer.State.testValue(metadata: .testValue()),
            reducer: {
                DocumentMetadataReducer()
            }
        )
    )
}
