import ApiInterface
import Components
import ComposableArchitecture
import DocumentsFeature
import Foundation
import Tagged

@Reducer
public struct OfflineListReducer: Sendable {

    @Reducer
    public enum Path {
        case documentDetail(DocumentDetailReducer)

        // The whole point of reusing the detail screen: every fetch it makes is pointed at the
        // record, so it reads with no connection. These five are the whole set — the detail's own
        // download, and the four the viewer sheet's sections reach. A sixth added to that screen
        // would compile, pass every other test, and only fail offline, which is what
        // `test_theDetailScreenReadsFromTheStoreRatherThanTheNetwork` is there to catch.
        @ReducerBuilder<State, Action>
        public static var body: some ReducerOf<Self> {
            EmptyReducer()
                .ifCaseLet(\.documentDetail, action: \.documentDetail) {
                    DocumentDetailReducer()
                        .dependency(\.downloadDocument, .offlineStore)
                        .dependency(\.getDocument, .offlineStore)
                        .dependency(\.getDocumentMetadata, .offlineStore)
                        .dependency(\.getDocumentsByIds, .offlineStore)
                        .dependency(\.getNotes, .offlineStore)
                }
        }
    }

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case offlineDocumentsChanged(IdentifiedArrayOf<OfflineDocument>)
        case path(StackActionOf<Path>)
        case refreshResult(Result<OfflineRefreshResult, Error>)
        case rows(IdentifiedActionOf<OfflineRowReducer>)
        case view(View)

        public enum View {
            case onAppear
            case onDisappear
            case onRefresh
        }
    }

    @ObservableState
    public struct State: Equatable {

        var path = StackState<Path.State>()

        // Stored rather than computed: `.forEach` scopes a child store out of stored state, and a
        // computed property has nothing for it to scope. Rebuilt whenever the offline documents or the
        // search text move.
        var rows: IdentifiedArrayOf<OfflineRowReducer.State> = []

        var searchText = ""

        let server: Server

        @Shared
        var offlineDocuments: IdentifiedArrayOf<OfflineDocument>

        // The `.inMemory` cache the documents and inbox lists project their rows out of. Read-side
        // only here: an offline document carries its own copy of the document, so without this the list
        // would show the pre-edit copy for the rest of the session — a refresh runs on pull or on
        // foreground, and an in-session edit is neither.
        @Shared
        var documentCache: IdentifiedArrayOf<Document>

        public init(server: Server) {
            self.server = server
            self._offlineDocuments = Shared(wrappedValue: [], .offlineDocuments(server))
            self._documentCache = Shared(wrappedValue: [], .documents(server))
            rebuildRows()
        }

        var visibleOfflineDocuments: IdentifiedArrayOf<OfflineDocument> {
            guard !searchText.isEmpty else {
                return offlineDocuments
            }

            let needle = searchText.lowercased()
            return offlineDocuments.filter { offlineDocument in
                let document = displayed(offlineDocument)
                let haystack = [
                    document.title,
                    document.content ?? "",
                    document.correspondent?.get(server)?.name ?? "",
                    document.documentType?.get(server)?.name ?? "",
                    document.storagePath?.get(server)?.name ?? "",
                ] + document.tags.compactMap { $0.get(server)?.name }

                return haystack.contains { $0.lowercased().contains(needle) }
            }
        }

        mutating func rebuildRows() {
            rows = IdentifiedArray(uniqueElements: visibleOfflineDocuments.map { offlineDocument in
                OfflineRowReducer.State(
                    document: reference(to: offlineDocument),
                    offlineDocument: offlineDocument,
                    server: server
                )
            })
        }

        // The offline detail is a window onto a record: removing deletes the PDF, so the screen
        // left behind can show its stored copy but nothing it re-fetches — the viewer's sections
        // throw `.notStored` — and it has no offline document button left to undo with. It is popped
        // wherever the removal came from, since the shared store is the one thing the detail's own
        // heart, a swipe on the row and "Remove all offline documents" in Settings all go through.
        mutating func popDetailsOfRemovedOfflineDocuments() {
            for (id, element) in zip(path.ids, path) {
                guard case let .documentDetail(detail) = element,
                      offlineDocuments[id: detail.document.id] == nil
                else {
                    continue
                }
                path.pop(from: id)
                break
            }
        }

        private func displayed(_ offlineDocument: OfflineDocument) -> Document {
            documentCache[id: offlineDocument.id] ?? offlineDocument.document
        }

        // The live copy when the cache has one, the stored snapshot otherwise. A cold launch and an
        // offline session get the snapshot, which is exactly when it is the only truth available.
        private func reference(to offlineDocument: OfflineDocument) -> Shared<Document> {
            Shared($documentCache[id: offlineDocument.id]) ?? Shared(value: offlineDocument.document)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchText):
                state.rebuildRows()
                return .none
            case .offlineDocumentsChanged:
                // Nothing is written back: the observer exists so an offline document removed by a swipe,
                // or added from the documents list, leaves and enters this list without waiting
                // for the next appearance.
                state.rebuildRows()
                return .none
            case let .refreshResult(result):
                state.rebuildRows()
                switch result {
                case let .success(summary):
                    return .toast(summary.toast)
                case let .failure(error):
                    return .toast(error)
                }
            case let .rows(.element(id: id, action: .delegate(.open(offlineDocument)))):
                state.path.append(.documentDetail(DocumentDetailReducer.State(
                    // The row's own reference, so an edit made in the detail reaches the row
                    // behind it rather than a copy of it.
                    document: state.rows[id: id]?.$document ?? Shared(value: offlineDocument.document),
                    // An offline document is a snapshot: read everything, change nothing.
                    isOfflineSnapshot: true,
                    server: state.server
                )))
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    return .runOfflineDocumentsObserver(server: state.server)
                case .onDisappear:
                    return .cancel(id: OfflineListCancelID.observeOfflineDocuments)
                case .onRefresh:
                    // Nothing guards against a second pull here, and nothing needs to: the effect
                    // shares its cancel id with AppFeature's automatic refresh, so overlap is
                    // settled by `cancelInFlight`. An in-flight flag would be worse than useless —
                    // a cancelled effect delivers no result to clear it, and the list would be
                    // locked out of pull-to-refresh for the rest of the session.
                    return .runRefreshOffline(server: state.server)
                }
            case .binding, .path, .rows:
                return .none
            }
        }
        .forEach(\.rows, action: \.rows) { OfflineRowReducer() }
        .forEach(\.path, action: \.path)

        // Last, and on every action rather than on the few that remove an offline document: the removal can
        // arrive from the detail's own heart, from the observer, or from another tab, and this is
        // the one place all of them are already past by the time it runs.
        Reduce { state, _ in
            state.popDetailsOfRemovedOfflineDocuments()
            return .none
        }
    }

    public init() {}
}

extension OfflineListReducer.Path.State: Equatable {}
