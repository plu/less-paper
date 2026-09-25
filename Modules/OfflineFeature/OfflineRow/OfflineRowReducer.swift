import ApiInterface
import ComposableArchitecture
import DocumentsFeature
import Foundation
import Tagged

@Reducer
public struct OfflineRowReducer: Sendable {

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Document.Id { offlineDocument.id }

        // What the row renders, which is not always `offline document.document`: the list hands over the
        // live cache entry where there is one, so an edit made elsewhere in the session shows here
        // too. The stored copy is what a cold launch and an offline session get.
        @Shared
        var document: Document

        var offlineDocument: OfflineDocument

        // The document list's row, scoped in only for what a swipe can do. Its own tap and its
        // delegates are not wired: this list opens rows its own way, and the one delegate that has
        // to be answered - delete - is handled below.
        var row: DocumentRowReducer.State

        let server: Server

        public init(document: Shared<Document>, offlineDocument: OfflineDocument, server: Server) {
            self._document = document
            self.offlineDocument = offlineDocument
            self.row = DocumentRowReducer.State(document: document, server: server)
            self.server = server
        }

        public init(offlineDocument: OfflineDocument, server: Server) {
            self.init(
                document: Shared(value: offlineDocument.document),
                offlineDocument: offlineDocument,
                server: server
            )
        }
    }

    public enum Action: ViewAction {
        case delegate(Delegate)
        case row(DocumentRowReducer.Action)
        case view(View)

        @CasePathable
        public enum Delegate {
            case open(OfflineDocument)
        }

        public enum View {
            case rowTapped
            case removeFromOfflineButtonTapped
        }
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.row, action: \.row) {
            DocumentRowReducer()
        }
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            // The row asks; this list is the only thing here that can answer. Without it a Delete
            // swipe would raise its confirmation, be confirmed, and do nothing at all.
            case .row(.delegate(.deleteDocument)):
                let id = state.id
                let server = state.server
                return .run { _ in
                    @Dependency(\.deleteDocuments.execute)
                    var deleteDocuments
                    try await deleteDocuments([id], server)
                } catch: { error, _ in
                    reportIssue(error)
                }
            case .row:
                return .none
            case .view(.rowTapped):
                return .send(.delegate(.open(state.offlineDocument)))
            case .view(.removeFromOfflineButtonTapped):
                let id = state.id
                let server = state.server
                return .run { _ in
                    @Dependency(\.removeOfflineDocument.execute) var removeOfflineDocument
                    try await removeOfflineDocument(id, server)
                }
            }
        }
    }

    public init() {}
}
