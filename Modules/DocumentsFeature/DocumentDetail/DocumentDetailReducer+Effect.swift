import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentDetailReducer.Action {

    static func runDownloadDocument(document: Document, server: Server) -> Self {
        .run { send in
            let file = try await document.download(server: server)
            await send(.downloadResult(.success(data: file.data, url: file.url)), animation: .default)
        } catch: { error, send in
            await send(.downloadResult(.failure(error.localizedDescription)))
        }
        .cancellable(id: CancelID.downloadDocument)
    }

    static func runToggleFavorite(document: Document, isFavorited: Bool, server: Server) -> Self {
        .run { send in
            if isFavorited {
                @Dependency(\.removeFavorite.execute)
                var removeFavorite
                try await removeFavorite(document.id, server)
            } else {
                @Dependency(\.saveFavorite.execute)
                var saveFavorite
                try await saveFavorite(document, server, .add)
            }
            await send(.favoriteToggleSucceeded)
        } catch: { error, send in
            await send(.favoriteToggleFailed(error))
        }
        .cancellable(id: CancelID.toggleFavorite)
    }
}

private enum CancelID {
    case downloadDocument
    case toggleFavorite
}
