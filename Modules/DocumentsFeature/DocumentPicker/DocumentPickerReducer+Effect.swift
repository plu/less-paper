import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import IdentifiedCollections

extension Effect where Action == DocumentPickerReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runSearch(_ state: DocumentPickerReducer.State) -> Self {
        @Dependency(\.getDocuments)
        var getDocuments

        let searchText = state.searchText
        let server = state.server

        return .run { send in
            let output = try await getDocuments.execute(
                GetDocumentsInput(
                    // `title__icontains`. The web's `title_search` resolves to the same query —
                    // verified identical for every term tried with `ordering=-created` pinned.
                    filterRules: searchText.isEmpty ? [] : [.init(ruleType: .title, value: searchText)],
                    sortDirection: .descending,
                    sortField: .created
                ),
                server
            )
            await send(.documentsLoaded(IdentifiedArray(uniqueElements: output.results)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    static func runSearchDebounce() -> Self {
        @Dependency(\.continuousClock)
        var clock

        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            await send(.searchDebounced)
        }
        .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)
    }
}

private enum CancelID {
    case search
    case searchDebounce
}
