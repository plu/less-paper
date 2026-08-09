import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentBulkEditGenericValueReducer.State where Value == Correspondent {

    static func testValue(
        documentCounts: [Value.ID: Int] = [:],
        documents: Set<Document.Id> = [10, 11],
        isLoading: Bool = false,
        isSaving: Bool = false,
        operation: DocumentBulkEditGenericValueReducer<Value>.Operation? = nil,
        searchText: String = "",
        server: Server = .testValue(),
        values: IdentifiedArrayOf<Correspondent> = [
            .testValue(id: 1, name: "C1"),
            .testValue(id: 2, name: "C2")
        ]
    ) -> Self {
        .init(
            documentCounts: documentCounts,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            operation: operation,
            searchText: searchText,
            server: server,
            values: values
        )
    }
}
