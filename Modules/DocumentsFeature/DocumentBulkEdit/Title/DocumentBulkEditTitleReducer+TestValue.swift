import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentBulkEditTitleReducer.State {

    static func testValue(
        documents: Set<Document.Id> = [10, 11],
        isLoading: Bool = false,
        isSaving: Bool = false,
        loadedDocuments: IdentifiedArrayOf<Document> = [],
        savedCount: Int = 0,
        server: Server = .testValue(),
        template: String = DocumentBulkEditTitlePlaceholder.title.rawValue
    ) -> Self {
        var state = Self(documents: documents, server: server)
        state.isLoading = isLoading
        state.isSaving = isSaving
        state.loadedDocuments = loadedDocuments
        state.savedCount = savedCount
        state.template = template
        return state
    }
}
