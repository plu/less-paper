import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentViewerReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case customFields(DocumentCustomFieldsReducer.Action)
        case destination(PresentationAction<Destination.Action>)
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

    // Swift allows the mutual recursion with DocumentDetailReducer, whose own Destination holds a
    // viewer; only the synthesised Equatable needs the hand-written conformance at the bottom of
    // this file, which every Destination in this codebase carries.
    @Reducer
    public enum Destination {
        case documentDetail(DocumentDetailReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        var destination: Destination.State?

        @Shared
        var document: Document

        var customFields: DocumentCustomFieldsReducer.State

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
            case .customFields:
                // The section scrolls its own content so the scroll view reaches the sheet's
                // edges, which the sheet's own padding would inset.
                return false
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

        // Carried only so a linked document opened from here inherits it: that document is a fresh
        // DocumentDetailReducer, not the one the Favorites tab already marked, and its own edit
        // form would otherwise reach the network same as any other document's.
        let isOfflineSnapshot: Bool

        var loadError: String?

        var metadata: DocumentMetadataReducer.State

        var notes: DocumentNotesReducer.State

        var section: DocumentViewerSection

        let server: Server

        init(
            document: Shared<Document>,
            isOfflineSnapshot: Bool = false,
            section: DocumentViewerSection = .content,
            server: Server
        ) {
            self._document = document
            self.customFields = DocumentCustomFieldsReducer.State(
                document: document,
                server: server
            )
            self.isOfflineSnapshot = isOfflineSnapshot
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
        Scope(state: \.customFields, action: \.customFields) {
            DocumentCustomFieldsReducer()
        }
        Scope(state: \.metadata, action: \.metadata) {
            DocumentMetadataReducer()
        }
        Scope(state: \.notes, action: \.notes) {
            DocumentNotesReducer()
        }
        Reduce { state, action in
            switch action {
            case let .customFields(.delegate(.openDocument(document))):
                state.destination = .documentDetail(DocumentDetailReducer.State(
                    document: Shared(value: document),
                    isOfflineSnapshot: state.isOfflineSnapshot,
                    server: state.server
                ))
                return .none
            case .customFields, .destination:
                return .none
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
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DocumentViewerReducer.Destination.State: Equatable {}
