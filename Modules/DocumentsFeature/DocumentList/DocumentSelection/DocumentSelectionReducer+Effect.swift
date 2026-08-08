import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentSelectionReducer.Action {
    static func runGetAllDocumentIds(
        filterRules: [FilterRule] = [],
        server: Server
    ) -> Self {
        @Dependency(\.getAllDocumentIds.execute)
        var getAllDocumentIds

        let input = GetAllDocumentIdsInput(
            filterRules: filterRules
        )

        return .run { send in
            let output = try await getAllDocumentIds(input, server)
            await send(.set(\.allMatchingDocuments, Set(output.results.map(\.id))))
            await send(.set(\.selectedDocuments, Set(output.results.map(\.id))))
            await send(.set(\.isLoading, false))
        } catch: { error, send in
            await send(.set(\.isLoading, false))
            await send(.error(error))
        }
        .cancellable(id: CancelID.getDocumentIds)
    }
}

private enum CancelID {
    case getDocumentIds
}
