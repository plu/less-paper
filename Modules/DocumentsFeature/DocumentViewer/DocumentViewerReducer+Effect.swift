import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentViewerReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    // Failure is swallowed deliberately: the detail has already been dismissed by the time this
    // runs, so there is no screen left to report onto, and the document simply stays. The list the
    // user returns to re-reads it on its next fetch.
    static func runDeleteDocument(id: Document.Id, server: Server) -> Self {
        .run { _ in
            @Dependency(\.deleteDocuments.execute)
            var deleteDocuments
            try? await deleteDocuments([id], server)
        }
    }

    static func runGetDocument(id: Document.Id, server: Server) -> Self {
        .run { send in
            @Dependency(\.getDocument.execute)
            var getDocument
            try await send(.documentResult(.success(getDocument(id, server))))
        } catch: { error, send in
            await send(.documentResult(.failure(error)))
        }
    }
}
