import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentHistoryReducer.Action {

    static func runGetDocumentHistory(
        documentId: Document.Id,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.getDocumentHistory.execute)
            var getDocumentHistory
            try await send(.historyResult(.success(getDocumentHistory(documentId, server))))
        } catch: { error, send in
            await send(.historyResult(.failure(error)))
        }
    }
}
