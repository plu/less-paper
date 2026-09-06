import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentDetailReducer.Action {

    // The same presenter and the same shape as the row's delete, so the two entrances to this
    // action ask the question identically. Only the delegate differs: the row's parent owns a
    // collection, and so does this screen's.
    static func runConfirmDelete(documentTitle: String, id: Document.Id) -> Self {
        @Dependency(\.documentDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentTitle) else {
                return
            }
            await send(.delegate(.deleteDocument(id)))
        }
        .cancellable(id: CancelID.confirmDelete)
    }

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
    case confirmDelete
    case downloadDocument
    case toggleFavorite
}
