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
                guard case let .failure(error) = result else {
                    return .none
                }
                return .toast(error)

            case .removed:
                state.totalByteCount = 0
                return .none

            case let .removeFailed(error):
                return .toast(error)

            case let .totalByteCountLoaded(count):
                state.totalByteCount = count
                return .none

            case .view(.onAppear):
                // Reloaded on every appearance rather than observed: the number is a directory
                // scan, not a value anything publishes changes to.
                return .run { [server = state.server] send in
                    await send(.totalByteCountLoaded(favoritesStore.totalByteCount(server)))
                }

            case .view(.redownloadAllButtonTapped):
                state.isWorking = true
                return .run { [server = state.server] send in
                    await send(.refreshResult(.success(try await refreshFavorites(true, server))))
                } catch: { error, send in
                    await send(.refreshResult(.failure(error)))
                }

            case .view(.removeAllButtonTapped):
                return .run { [server = state.server] send in
                    guard await presentConfirmation(.removeAllFavorites, String(localized: .favorites)) else {
                        return
                    }

                    do {
                        try await favoritesStore.deleteAll(server)
                    } catch {
                        await send(.removeFailed(error))
                        return
                    }

                    // The record and the file are two different stores by design (four tasks worth
                    // of reasons); removing all favorites must not leave either behind.
                    @Shared(.favorites(server)) var favorites: IdentifiedArrayOf<FavoriteDocument> = []
                    $favorites.withLock { $0.removeAll() }

                    await send(.removed)
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
}
