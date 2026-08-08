import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentListReducer.State {

    static func testValue(
        destination: DocumentListReducer.Destination.State? = nil,
        documents: IdentifiedArrayOf<DocumentRowReducer.State> = [
            .testValue(document: .testValue(id: 1, tags: [1, 2], title: "Doc 1")),
            .testValue(document: .testValue(id: 2, tags: [3, 4], title: "Doc 2")),
            .testValue(document: .testValue(id: 3, tags: [5, 6, 7, 8], title: "Doc 3")),
            .testValue(document: .testValue(id: 4, tags: [], title: "Doc 4")),
        ],
        documentSelection: DocumentSelectionReducer.State = .testValue(),
        error: String? = nil,
        filter: DocumentFilter = .testValue(),
        isLoaded: Bool = false,
        isLoadingMore: Bool = false,
        nextPage: URL? = nil,
        path: StackState<DocumentListReducer.Path.State> = .init(),
        server: Server = .testValue(),
        totalNumberOfDocuments: Int = 42
    ) -> Self {
        .init(
            destination: destination,
            documentSelection: documentSelection,
            documents: documents,
            error: error,
            filter: filter,
            isLoaded: isLoaded,
            isLoadingMore: isLoadingMore,
            nextPage: nextPage,
            path: path,
            server: server,
            totalNumberOfDocuments: totalNumberOfDocuments
        )
    }
}
