import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing

extension Effect where Action == ServerListReducer.Action {
    static func runDeleteFavorites(
        server: Server?
    ) -> Self {
        guard let server else {
            return .none
        }

        @Dependency(\.favoritesStore.deleteAll)
        var deleteAllFavorites

        return .run { _ in
            // The record and the file are two different stores by design; a deleted server must not
            // leave either behind, or its bytes outlive the server that explains them.
            //
            // The records go first, as in RemoveFavoriteUseCase. Deleting the files first leaves a
            // window in which a refresh's save, already past its download, still sees its record,
            // writes its PDF and recreates the directory being cleared. Dropping the records first
            // means that save fails its own membership check and cleans up after itself instead.
            @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []
            $favorites.withLock { $0.removeAll() }

            try await deleteAllFavorites(server)
        } catch: { _, _ in
        }
    }

    static func runGetCredentials(
        server: Server?
    ) -> Self {
        guard let server else {
            return .none
        }

        @Dependency(\.getCredentials.execute)
        var getCredentials

        return .run { send in
            try await send(.getCredentialsResult(getCredentials(server), server))
        } catch: { _, send in
            await send(.getCredentialsResult(nil, server))
        }
        .cancellable(id: CancelID.getCredentials)
    }
}

private enum CancelID {
    case getCredentials
}
