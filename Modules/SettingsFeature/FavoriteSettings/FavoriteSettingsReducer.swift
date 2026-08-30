import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftSharing

@Reducer
public struct FavoriteSettingsReducer: Sendable {

    @ObservableState
    public struct State: Equatable {

        var isWorking = false

        let server: Server

        var totalByteCount = 0

        public init(
            server: Server,
            isWorking: Bool = false,
            totalByteCount: Int = 0
        ) {
            self.server = server
            self.isWorking = isWorking
            self.totalByteCount = totalByteCount
        }
    }

    public enum Action: ViewAction {
        case refreshResult(Result<FavoriteRefreshResult, Error>)
        case removeConfirmed
        case removed
        case removeFailed(Error)
        case totalByteCountLoaded(Int)
        case view(View)

        public enum View {
            case onAppear
            case redownloadAllButtonTapped
            case removeAllButtonTapped
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .refreshResult(result):
                state.isWorking = false
                switch result {
                case let .success(summary):
                    // A redownload rewrites every stored PDF, so the size above it is stale the
                    // moment it finishes.
                    return .merge(
                        .toast(summary.toast),
                        loadTotalByteCount(server: state.server)
                    )
                case let .failure(error):
                    return .toast(error)
                }

            case .removeConfirmed:
                state.isWorking = true
                return .run { [server = state.server] send in
                    // The records go first, as in RemoveFavoriteUseCase. Deleting the files first
                    // leaves a window in which a refresh's save, already past its download, still
                    // sees its record, writes its PDF and recreates the directory being cleared.
                    // Dropping the records first means that save fails its own membership check and
                    // cleans up after itself instead.
                    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []
                    $favorites.withLock { $0.removeAll() }

                    do {
                        try await favoritesStore.deleteAll(server)
                    } catch {
                        await send(.removeFailed(error))
                        return
                    }

                    await send(.removed)
                }

            case .removed:
                state.isWorking = false
                state.totalByteCount = 0
                return .none

            case let .removeFailed(error):
                state.isWorking = false
                // Reloaded rather than assumed: the records are gone by now, and whatever the
                // failure left on disk is what the number should say.
                return .merge(
                    .toast(error),
                    loadTotalByteCount(server: state.server)
                )

            case let .totalByteCountLoaded(count):
                state.totalByteCount = count
                return .none

            case .view(.onAppear):
                // Reloaded on every appearance rather than observed: the number is a directory
                // scan, not a value anything publishes changes to.
                return loadTotalByteCount(server: state.server)

            case .view(.redownloadAllButtonTapped):
                state.isWorking = true
                return .run { [server = state.server] send in
                    await send(.refreshResult(.success(try await refreshFavorites(true, server))))
                } catch: { error, send in
                    await send(.refreshResult(.failure(error)))
                }

            case .view(.removeAllButtonTapped):
                // `isWorking` is set by `removeConfirmed` rather than here, so declining the
                // confirmation needs no action of its own to put the buttons back.
                return .run { [server = state.server] send in
                    guard await presentConfirmation(.removeAllFavorites, String(localized: .favorites)) else {
                        return
                    }
                    await send(.removeConfirmed)
                }
            }
        }
    }

    public init() {}

    @Dependency(\.deleteConfirmation.present)
    private var presentConfirmation

    @Dependency(\.favoritesStore)
    private var favoritesStore

    @Dependency(\.refreshFavorites.execute)
    private var refreshFavorites

    private func loadTotalByteCount(server: Server) -> Effect<Action> {
        .run { send in
            await send(.totalByteCountLoaded(favoritesStore.totalByteCount(server)))
        }
    }
}
