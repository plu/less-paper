import ApiInterface
import Foundation

extension DocumentHistoryReducer.State {

    static func testValue(
        documentId: Document.Id = 1,
        entries: [AuditLogEntry]? = nil,
        isLoading: Bool = false,
        loadError: String? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            documentId: documentId,
            server: server
        )
        state.entries = entries
        state.isLoading = isLoading
        state.loadError = loadError
        return state
    }
}
