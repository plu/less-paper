import ApiInterface
import Foundation
import IdentifiedCollections
import SwiftSharing

extension DocumentViewerReducer.State {

    static func testValue(
        document: Document = .testValue(),
        hasLoadedContent: Bool = false,
        loadError: String? = nil,
        metadata: DocumentMetadata? = nil,
        notes: IdentifiedArrayOf<Note>? = nil,
        section: DocumentViewerSection = .content,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            document: Shared(value: document),
            section: section,
            server: server
        )
        state.hasLoadedContent = hasLoadedContent
        state.loadError = loadError
        state.metadata.metadata = metadata
        state.notes.notes = notes
        return state
    }
}
