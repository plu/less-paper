import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentListReducer.Action {

    static func runGetDocuments(
        filterRules: [FilterRule] = [],
        server: Server,
        sortDirection: SortDirection,
        sortField: SortField
    ) -> Self {
        @Dependency(\.getDocuments.execute)
        var getDocuments

        let input = GetDocumentsInput(
            filterRules: filterRules,
            sortDirection: sortDirection,
            sortField: sortField
        )

        return .run { send in
            try await send(.replaceDocuments(getDocuments(input, server)), animation: .none)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getDocuments)
    }

    static func runGetMoreDocuments(
        server: Server,
        url: URL
    ) -> Self {
        @Dependency(\.getDocuments.execute)
        var getDocuments

        return .run { send in
            try await send(.appendDocuments(getDocuments(.init(url: url), server)), animation: .none)
            await send(.set(\.isLoadingMore, false))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoadingMore, false))
        }
        .cancellable(id: CancelID.getDocuments)
    }
}

private enum CancelID {
    case getDocuments
    case getMoreDocuments
}
