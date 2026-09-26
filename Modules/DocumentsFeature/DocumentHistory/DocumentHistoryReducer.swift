import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentHistoryReducer: Sendable {

    public enum Action: ViewAction {
        case historyResult(Result<[AuditLogEntry], Error>)
        case view(View)

        public enum View {
            case onAppear
            case retryLoadButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        let documentId: Document.Id

        // nil until the first load lands; an empty array means loaded with nothing to show.
        var entries: [AuditLogEntry]?

        var isLoading = false

        var loadError: String?

        let server: Server

        init(
            documentId: Document.Id,
            server: Server
        ) {
            self.documentId = documentId
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .historyResult(result):
                state.isLoading = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(entries):
                    state.loadError = nil
                    state.entries = entries
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    // Switching sections away and back must not refetch, and a failed load is not
                    // retried silently — that is what the retry button is for.
                    guard state.entries == nil, state.loadError == nil, !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetDocumentHistory(
                        documentId: state.documentId,
                        server: state.server
                    )
                case .retryLoadButtonTapped:
                    guard !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    state.loadError = nil
                    return .runGetDocumentHistory(
                        documentId: state.documentId,
                        server: state.server
                    )
                }
            }
        }
    }
}
