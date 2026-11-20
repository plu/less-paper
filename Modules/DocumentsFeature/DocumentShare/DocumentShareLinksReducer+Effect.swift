import ApiInterface
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentShareLinksReducer.Action {

    static func runConfirmDelete(link: ShareLink) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteShareLink, link.slug) else {
                return
            }
            await send(.deleteConfirmed(link.id))
        }
        .cancellable(id: DocumentShareLinksReducer.CancelID.confirmDelete)
    }

    static func runCreateShareLink(input: CreateShareLinkInput, server: Server) -> Self {
        .run { send in
            @Dependency(\.createShareLink.execute)
            var createShareLink
            try await send(.createResult(.success(createShareLink(input, server))))
        } catch: { error, send in
            await send(.createResult(.failure(error)))
        }
        .cancellable(id: DocumentShareLinksReducer.CancelID.create)
    }

    static func runDeleteShareLink(id: ShareLink.Id, server: Server) -> Self {
        .run { send in
            @Dependency(\.deleteShareLink.execute)
            var deleteShareLink
            try await send(.deleteResult(id, .success(deleteShareLink(id, server))))
        } catch: { error, send in
            await send(.deleteResult(id, .failure(error)))
        }
        .cancellable(id: DocumentShareLinksReducer.CancelID.delete)
    }

    static func runGetShareLinks(documentId: Document.Id, server: Server) -> Self {
        .run { send in
            @Dependency(\.getShareLinks.execute)
            var getShareLinks
            try await send(.linksResult(.success(getShareLinks(documentId, server))))
        } catch: { error, send in
            await send(.linksResult(.failure(error)))
        }
        .cancellable(id: DocumentShareLinksReducer.CancelID.load)
    }
}
