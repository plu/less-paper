import ApiInterface
import ComposableArchitecture
import Foundation

extension DocumentBulkEditMergeReducer.State {

    static func testValue(
        deleteOriginals: Bool = false,
        documents: [Document] = [
            .testValue(id: 1, title: "Invoice"),
            .testValue(id: 2, title: "Receipt")
        ],
        isLoading: Bool = false,
        isSaving: Bool = false,
        selectedDocuments: Set<Document.Id> = [1, 2],
        server: Server = .testValue(),
        sort: DocumentFilterInput.SortFilter = .init()
    ) -> Self {
        .init(
            deleteOriginals: deleteOriginals,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            selectedDocuments: selectedDocuments,
            server: server,
            sort: sort
        )
    }
}
