import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing

extension Effect where Action == FavoriteListReducer.Action {

    static func runFavoritesObserver(server: Server) -> Self {
        @Shared(.favorites(server))
        var favorites: IdentifiedArrayOf<FavoriteDocument>

        return .publisher {
            $favorites
                .publisher
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .map(Action.favoritesChanged)
        }
        .cancellable(
            id: FavoriteListCancelID.observeFavorites,
            cancelInFlight: true
        )
    }

    static func runRefreshFavorites(server: Server) -> Self {
        @Dependency(\.refreshFavorites.execute)
        var refreshFavorites

        return .run { send in
            await send(.refreshResult(.success(try await refreshFavorites(false, server))))
        } catch: { error, send in
            await send(.refreshResult(.failure(error)))
        }
        // Shared with AppFeature's automatic refresh, which runs over the same records and the same
        // PDF paths: one identity is what keeps the two from downloading everything twice.
        .cancellable(
            id: RefreshFavoritesCancelID.refresh,
            cancelInFlight: true
        )
    }
}

enum FavoriteListCancelID {
    case observeFavorites
}
