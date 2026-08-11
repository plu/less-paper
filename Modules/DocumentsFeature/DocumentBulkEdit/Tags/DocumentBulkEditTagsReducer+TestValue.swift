import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentBulkEditTagsReducer.State {

    static func testValue(
        documentCounts: [Tag.Id: Int] = [:],
        documents: Set<Document.Id> = [10, 11],
        isLoading: Bool = false,
        isSaving: Bool = false,
        operations: [Tag.Id: DocumentBulkEditTagsReducer.Operation] = [:],
        searchText: String = "",
        server: Server = .testValue(),
        values: IdentifiedArrayOf<Tag> = [
            .testValue(id: 1, name: "T1"),
            .testValue(id: 2, name: "T2")
        ]
    ) -> Self {
        .init(
            documentCounts: documentCounts,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            operations: operations,
            searchText: searchText,
            server: server,
            values: values
        )
    }
}
