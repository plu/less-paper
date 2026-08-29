import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentRowReducer.Action {

    static func runConfirmDelete(documentTitle: String) -> Self {
        @Dependency(\.documentDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentTitle) else {
                return
            }
            await send(.delegate(.deleteDocument))
        }
        .cancellable(id: CancelID.confirmDelete)
    }

    static func runDownloadDocument(
        document: Document,
        intent: DocumentRowReducer.DownloadIntent,
        server: Server
    ) -> Self {
        .run { send in
            let file = try await document.download(server: server)
            await send(.downloadSucceeded(url: file.url, intent: intent), animation: .default)
        } catch: { error, send in
            await send(.downloadFailed(error))
        }
        .cancellable(id: CancelID.downloadDocument(document.id))
    }

    static func runToggleFavorite(
        document: Document,
        isFavorited: Bool,
        server: Server
    ) -> Self {
        .run { _ in
            if isFavorited {
                @Dependency(\.removeFavorite.execute)
                var removeFavorite
                try await removeFavorite(document.id, server)
            } else {
                @Dependency(\.saveFavorite.execute)
                var saveFavorite
                try await saveFavorite(document, server, .add)
            }
        }
        .cancellable(id: CancelID.toggleFavorite(document.id))
    }
}

// Keyed by document: a bare case would make a tap on one row cancel another row's download.
private enum CancelID: Hashable {
    case confirmDelete
    case downloadDocument(Document.Id)
    case toggleFavorite(Document.Id)
}
