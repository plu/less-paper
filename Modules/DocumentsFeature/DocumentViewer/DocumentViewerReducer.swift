import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentViewerReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case documentResult(Result<Document, Error>)
        case metadata(DocumentMetadataReducer.Action)
        case notes(DocumentNotesReducer.Action)
        case view(View)

        public enum View {
            case closeButtonTapped
            case onAppear
            case retryLoadButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        @Shared
        var document: Document

        // The list payload carries a truncated content string, so `document.content` is never a
        // reliable signal that the full text has arrived. This flag is.
        var hasLoadedContent = false

        // Only real text scrolls. The loading, error and empty states are centred in the sheet
        // instead, which its ScrollView would otherwise pin to the top. Notes never scroll the
        // sheet: the list inside them scrolls itself.
        var isContentScrollable: Bool {
            switch section {
            case .content:
                guard hasLoadedContent, loadError == nil else {
                    return false
                }
                return !(document.content ?? "").isEmpty
            case .metadata:
                guard let value = metadata.metadata, metadata.loadError == nil else {
                    return false
                }
                return !value.isEmpty
            case .notes:
                return false
            }
        }

        var isLoadingDocument = false

        var loadError: String?

        var metadata: DocumentMetadataReducer.State

        var notes: DocumentNotesReducer.State

        var section: DocumentViewerSection

        let server: Server

        init(
            document: Shared<Document>,
            section: DocumentViewerSection = .content,
            server: Server
        ) {
            self._document = document
            self.metadata = DocumentMetadataReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.notes = DocumentNotesReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.section = section
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.metadata, action: \.metadata) {
            DocumentMetadataReducer()
        }
        Scope(state: \.notes, action: \.notes) {
            DocumentNotesReducer()
        }
        Reduce { state, action in
            switch action {
            case let .documentResult(result):
                state.isLoadingDocument = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(document):
                    state.hasLoadedContent = true
                    state.loadError = nil
                    state.$document.withLock { $0 = document }
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .onAppear:
                    // A failed load is not retried silently on the next appearance; that is what
                    // the retry button is for. Switching sections away and back must not refetch
                    // either, which is what the loaded check buys.
                    guard !state.hasLoadedContent, state.loadError == nil, !state.isLoadingDocument else {
                        return .none
                    }
                    state.isLoadingDocument = true
                    return .runGetDocument(
                        id: state.document.id,
                        server: state.server
                    )
                case .retryLoadButtonTapped:
                    guard !state.isLoadingDocument else {
                        return .none
                    }
                    state.isLoadingDocument = true
                    state.loadError = nil
                    return .runGetDocument(
                        id: state.document.id,
                        server: state.server
                    )
                }
            case .binding, .metadata, .notes:
                return .none
            }
        }
    }
}
