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
