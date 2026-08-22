import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentMetadataReducer: Sendable {

    public enum Action: ViewAction {
        case metadataResult(Result<DocumentMetadata, Error>)
        case view(View)

        public enum View {
            case onAppear
            case retryLoadButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        let documentId: Document.Id

        var isLoading = false

        var loadError: String?

        // nil until the first load lands, which is what separates "still loading" from "loaded"
        // without a second flag — a loaded document can have every field empty.
        var metadata: DocumentMetadata?

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
            case let .metadataResult(result):
                state.isLoading = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(metadata):
                    state.loadError = nil
                    state.metadata = metadata
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    // Switching sections away and back must not refetch, and a failed load is not
                    // retried silently — that is what the retry button is for.
                    guard state.metadata == nil, state.loadError == nil, !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetDocumentMetadata(
                        documentId: state.documentId,
                        server: state.server
                    )
                case .retryLoadButtonTapped:
                    guard !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    state.loadError = nil
                    return .runGetDocumentMetadata(
                        documentId: state.documentId,
                        server: state.server
                    )
                }
            }
        }
    }
}
