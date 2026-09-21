import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentSearchReducer.Action {

    static func runCancelSearch() -> Self {
        .cancel(id: CancelID.search)
    }

    static func runGlobalSearch(query: String, server: Server) -> Self {
        .run { send in
            @Dependency(\.globalSearch.execute)
            var globalSearch

            try await send(.results(globalSearch(query, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    // Carries no query on purpose: the reducer reads state when `searchDebounced` lands.
    static func runSearchDebounce() -> Self {
        @Dependency(\.continuousClock)
        var clock

        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.searchDebounced)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

// One id for the debounce and the request together, unlike the two ids DocumentFilterReducer keeps.
// A keystroke has to cancel a request already in flight as well as a pending sleep, and a second id
// would leave the older request to land after the newer one.
private enum CancelID {
    case search
}
