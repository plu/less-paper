import ApiInterface
import IdentifiedCollections

extension CustomFieldQueryDocumentPickerReducer.State {
    static func testValue(
        documents: IdentifiedArrayOf<Document> = [],
        isLoading: Bool = false,
        searchText: String = "",
        selection: IdentifiedArrayOf<Document> = [],
        server: Server = .testValue()
    ) -> Self {
        .init(
            documents: documents,
            isLoading: isLoading,
            searchText: searchText,
            selection: selection,
            server: server
        )
    }
}
