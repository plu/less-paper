import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentMetadataReducer.Action {

    static func runGetDocumentMetadata(
        documentId: Document.Id,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.getDocumentMetadata.execute)
            var getDocumentMetadata
            try await send(.metadataResult(.success(getDocumentMetadata(documentId, server))))
        } catch: { error, send in
            await send(.metadataResult(.failure(error)))
        }
    }
}
