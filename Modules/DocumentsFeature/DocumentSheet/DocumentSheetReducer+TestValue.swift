import ApiInterface
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DocumentSheetReducer.State {

    static func testValue(
        content: String? = nil,
        customFields: IdentifiedArrayOf<CustomField> = [],
        destination: DocumentSheetReducer.Destination.State? = nil,
        document: Document = .testValue(),
        history: [AuditLogEntry]? = nil,
        isOfflineSnapshot: Bool = false,
        loadError: String? = nil,
        metadata: DocumentMetadata? = nil,
        notes: IdentifiedArrayOf<Note>? = nil,
        section: DocumentSheetSection = .details,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            destination: destination,
            document: Shared(value: document),
            isOfflineSnapshot: isOfflineSnapshot,
            server: server
        )
        state.$customFields.withLock { $0 = customFields }
        state.content = content
        state.history.entries = history
        state.loadError = loadError
        state.metadata.metadata = metadata
        state.notes.notes = notes
        state.section = section
        return state
    }
}
