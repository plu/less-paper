import ApiInterface
import Foundation

extension DocumentMetadataReducer.State {

    static func testValue(
        documentId: Document.Id = 1,
        isLoading: Bool = false,
        loadError: String? = nil,
        metadata: DocumentMetadata? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            documentId: documentId,
            server: server
        )
        state.isLoading = isLoading
        state.loadError = loadError
        state.metadata = metadata
        return state
    }
}
