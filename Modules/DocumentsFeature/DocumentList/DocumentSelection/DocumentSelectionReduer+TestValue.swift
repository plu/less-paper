import ApiInterface
import Foundation

extension DocumentSelectionReducer.State {
    static func testValue(
        allLoadedDocuments: Set<Document.Id> = .init(),
        allMatchingDocuments: Set<Document.Id> = .init(),
        isActive: Bool = false,
        selectedDocuments: Set<Document.Id> = .init(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            allLoadedDocuments: allLoadedDocuments,
            allMatchingDocuments: allMatchingDocuments,
            isActive: isActive,
            selectedDocuments: selectedDocuments,
            server: server
        )
    }
}
