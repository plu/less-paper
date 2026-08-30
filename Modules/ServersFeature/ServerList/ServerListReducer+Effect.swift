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
            try await deleteAllFavorites(server)

            // The record and the file are two different stores by design; a deleted server
            // must not leave either behind, or its bytes outlive the server that explains them.
            @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []
            $favorites.withLock { $0.removeAll() }
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
