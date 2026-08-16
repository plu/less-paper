import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import ShareFeature
import Tagged

@Reducer
public struct DocumentListReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case appendDocuments(GetDocumentsOutput)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case deleteDocumentsFailed(ids: Set<Document.Id>, error: Error)
        case deleteSelectedConfirmed
        case destination(PresentationAction<Destination.Action>)
        case documentImport(DocumentImportReducer.Action)
        case documentSelection(DocumentSelectionReducer.Action)
        case documents(IdentifiedActionOf<DocumentRowReducer>)
        case documentsDeleted(Set<Document.Id>)
        case documentsRefreshed([Document])
        case error(Error)
        case isUpdating(ids: Set<Document.Id>, isUpdating: Bool)
        case path(StackActionOf<Path>)
        case replaceDocuments(GetDocumentsOutput)
        case view(View)

        public enum Delegate: Equatable {
            case documentsDeleted(Set<Document.Id>)
        }

        public enum View {
            case allDocumentsButtonTapped
            case deleteSelectedButtonTapped
            case editCorrespondentButtonTapped
            case editDocumentTypeButtonTapped
            case editStoragePathButtonTapped
            case editTagsButtonTapped
            case editTitleButtonTapped
            case filterButtonTapped
            case importButtonTapped
            case onAppear
            case onRefresh
            case onRowAppear(Document)
            case reloadButtonTapped
            case savedViewButtonTapped(SavedView)
            case scanButtonTapped
            case serverButtonTapped(Server)
            case toggleSelectionModeButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>)
        case bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>)
        case bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>)
        case bulkEditTags(DocumentBulkEditTagsReducer)
        case bulkEditTitle(DocumentBulkEditTitleReducer)
        case documentFilter(DocumentFilterReducer)
    }

    @Reducer
    public enum Path {
        case documentDetail(DocumentDetailReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        @Presents
        var destination: Destination.State?

        var documentImport = DocumentImportReducer.State()

        var documentSelection: DocumentSelectionReducer.State

        var documents: IdentifiedArrayOf<DocumentRowReducer.State>

        var error: String?

        var filter = DocumentFilter()

        var hasActiveFilter: Bool {
            filter.input != DocumentFilterInput() || filter.savedView != nil
        }

        var isLoaded: Bool

        var isLoadingMore: Bool

        var navigationTitle: LocalizedStringResource {
            if let savedView = filter.savedView {
                return .init(stringLiteral: savedView.name)
            }
            return .allDocuments
        }

        var nextPage: URL?

        var path: StackState<Path.State>

        @Shared
        var correspondents: IdentifiedArrayOf<Correspondent>

        @Shared
        var documentCache: IdentifiedArrayOf<Document>

        @Shared
        var documentTypes: IdentifiedArrayOf<DocumentType>

        // Carries its key in the attribute rather than being assigned in `init`, like `servers`
        // below: it is presentation state for the filter sheet and its pickers, not scoped to a
        // server.
        @Shared(.documentFilterMatchCount)
        var filterMatchCount: DocumentFilterMatchCount

        @Shared
        var savedViews: IdentifiedArrayOf<SavedView>

        // Carries its key in the attribute rather than being assigned in `init`: unlike its
        // neighbours this one is not scoped to `server`, so it has nothing to wait for.
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        @Shared
        var storagePaths: IdentifiedArrayOf<StoragePath>

        @Shared
        var tags: IdentifiedArrayOf<Tag>

        var totalNumberOfDocuments: Int

        public init(
            destination: Destination.State? = nil,
            documentSelection: DocumentSelectionReducer.State? = nil,
            documents: IdentifiedArrayOf<DocumentRowReducer.State> = [],
            error: String? = nil,
            filter: DocumentFilter? = nil,
            isLoaded: Bool = false,
            isLoadingMore: Bool = false,
            nextPage: URL? = nil,
            path: StackState<Path.State> = .init(),
            server: Server,
            totalNumberOfDocuments: Int = 0
        ) {
            self.destination = destination
            self.documents = documents
            self.documentSelection = documentSelection ?? DocumentSelectionReducer.State(server: server)
            self.error = error
            self.filter = filter ?? .init()
            self.isLoaded = isLoaded
            self.isLoadingMore = isLoadingMore
            self.nextPage = nextPage
            self.path = path
            self.server = server
            self.totalNumberOfDocuments = totalNumberOfDocuments
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._documentCache = Shared(wrappedValue: [], .documents(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._savedViews = Shared(wrappedValue: [], .savedViews(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
        }

        var isInboxWithoutInboxTags: Bool {
            filter.isInbox && filter.input.tag.selection.any.isEmpty
        }

        mutating func clearForEmptyInbox() {
            documents = []
            documentSelection.allLoadedDocuments = []
            isLoaded = true
            nextPage = nil
            totalNumberOfDocuments = 0
        }

        // Scoped to the filter flow being on screen: the count is presentation state for that sheet
        // and its pickers, so writing it from every list fetch would leave a value nothing reads
        // and make every unrelated list test assert it.
        mutating func updateFilterMatchCount(_ body: (inout DocumentFilterMatchCount) -> Void) {
            guard destination?.documentFilter != nil else {
                return
            }
            $filterMatchCount.withLock(body)
        }

        mutating func rebuildInboxFilterIfNeeded() {
            guard filter.isInbox else {
                return
            }
            filter = .inbox(server: server)
        }

        func cacheDocuments(_ documents: [Document]) {
            $documentCache.withLock { cache in
                for document in documents {
                    cache.updateOrAppend(document)
                }
            }
        }

        func rows(for documents: [Document]) -> IdentifiedArrayOf<DocumentRowReducer.State> {
            cacheDocuments(documents)
            return IdentifiedArray(uniqueElements: documents.map { document in
                DocumentRowReducer.State(
                    document: Shared($documentCache[id: document.id])!,
                    server: server
                )
            })
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.documentImport, action: \.documentImport) {
            DocumentImportReducer()
        }
        Scope(state: \.documentSelection, action: \.documentSelection) {
            DocumentSelectionReducer()
        }
        Reduce { state, action in
            switch action {
            case let .appendDocuments(output):
                let rows = state.rows(for: output.results)
                state.documents.append(contentsOf: rows)
                state.documentSelection.allLoadedDocuments.formUnion(Set(output.results.map(\.id)))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
                return .none
            case .deleteSelectedConfirmed:
                // Selection mode collapses on commit rather than in `documentsDeleted`, which
                // `MainReducer` forwards to the other tab — that tab's selection is not ours to
                // close.
                let ids = state.documentSelection.selectedDocuments
                state.documentSelection.isActive = false
                return .runDeleteDocuments(ids: ids, server: state.server)
            case let .deleteDocumentsFailed(ids: ids, error: error):
                for id in ids {
                    state.documents[id: id]?.isUpdating = false
                }
                return .toast(error)
            case let .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated(ids))))),
                 let .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated(ids))))):
                state.destination = nil
                return .merge(
                    .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    ),
                    .runRefreshDocuments(
                        ids: Set(state.documentCache.ids).intersection(ids),
                        server: state.server
                    )
                )
            case let .destination(.presented(.bulkEditTitle(.delegate(.documentsUpdated(ids))))):
                // No `destination = nil` here, unlike its four siblings above: after a partial
                // failure the sheet stays open holding the documents that failed, while the ones
                // that were renamed still reach the list. Full success dismisses from inside the
                // sheet instead.
                return .merge(
                    .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    ),
                    .runRefreshDocuments(
                        ids: Set(state.documentCache.ids).intersection(ids),
                        server: state.server
                    )
                )
            case let .destination(.presented(.documentFilter(.delegate(delegateAction)))):
                switch delegateAction {
                case let .filterUpdated(filter):
                    state.error = nil
                    state.filter = filter
                    state.updateFilterMatchCount { $0.isRecalculating = true }
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                }
            case let .documents(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteDocument:
                    return .runDeleteDocuments(ids: [id], server: state.server)
                case let .presentDocumentDetail(document):
                    state.path.append(.documentDetail(DocumentDetailReducer.State(
                        document: document,
                        server: state.server
                    )))
                    return .none
                }
            case let .documentsDeleted(ids):
                let countBefore = state.documents.count
                state.documents.removeAll { ids.contains($0.id) }
                state.documentSelection.allLoadedDocuments.subtract(ids)
                state.documentSelection.allMatchingDocuments.subtract(ids)
                state.documentSelection.selectedDocuments.subtract(ids)
                // Cleared by id rather than with `removeAll(where:)`: the latter rebuilds the
                // stack through `replaceSubrange`, which hands the surviving screens fresh
                // `StackElementID`s and makes SwiftUI treat them as new pushes.
                for elementId in state.path.ids {
                    guard case let .documentDetail(detail) = state.path[id: elementId],
                          ids.contains(detail.document.id)
                    else {
                        continue
                    }
                    state.path[id: elementId] = nil
                }
                state.totalNumberOfDocuments = max(
                    0,
                    state.totalNumberOfDocuments - (countBefore - state.documents.count)
                )
                return .none
            case let .documentsRefreshed(documents):
                state.cacheDocuments(documents)
                return .none
            case let .error(error):
                state.error = error.localizedDescription
                // The count is deliberately left alone: it is the last number that was true, and
                // blanking it would tell the user the filter matches nothing.
                state.updateFilterMatchCount { $0.isRecalculating = false }
                return .toast(error)
            case let .isUpdating(ids: ids, isUpdating: isUpdating):
                for id in ids {
                    state.documents[id: id]?.isUpdating = isUpdating
                }
                return .none
            case let .replaceDocuments(output):
                state.documents = state.rows(for: output.results)
                state.documentSelection.allLoadedDocuments = Set(output.results.map(\.id))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
                state.updateFilterMatchCount {
                    $0.count = output.count
                    $0.isRecalculating = false
                }
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .allDocumentsButtonTapped:
                    state.error = nil
                    state.filter = .init()
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                case .deleteSelectedButtonTapped:
                    guard !state.documentSelection.selectedDocuments.isEmpty else {
                        return .none
                    }
                    return .runConfirmDeleteSelected(
                        documentCount: state.documentSelection.selectedDocuments.count
                    )
                case .editCorrespondentButtonTapped:
                    state.destination = .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.correspondents
                    ))
                    return .none
                case .editDocumentTypeButtonTapped:
                    state.destination = .bulkEditDocumentType(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.documentTypes
                    ))
                    return .none
                case .editStoragePathButtonTapped:
                    state.destination = .bulkEditStoragePath(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.storagePaths
                    ))
                    return .none
                case .editTagsButtonTapped:
                    state.destination = .bulkEditTags(DocumentBulkEditTagsReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.tags
                    ))
                    return .none
                case .editTitleButtonTapped:
                    state.destination = .bulkEditTitle(DocumentBulkEditTitleReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server
                    ))
                    return .none
                case .filterButtonTapped:
                    state.$filterMatchCount.withLock {
                        $0 = .init(count: state.isLoaded ? state.totalNumberOfDocuments : nil)
                    }
                    state.destination = .documentFilter(DocumentFilterReducer.State(
                        input: state.filter.input,
                        savedView: state.filter.savedView,
                        server: state.server
                    ))
                    return .none
                case .importButtonTapped:
                    return .send(.documentImport(.view(.importButtonTapped)))
                case .onAppear:
                    guard state.documents.isEmpty else {
                        return .none
                    }
                    state.error = nil
                    state.rebuildInboxFilterIfNeeded()
                    guard !state.isInboxWithoutInboxTags else {
                        state.clearForEmptyInbox()
                        return .none
                    }
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                case .onRefresh, .reloadButtonTapped:
                    state.error = nil
                    state.rebuildInboxFilterIfNeeded()
                    guard !state.isInboxWithoutInboxTags else {
                        state.clearForEmptyInbox()
                        return .runRefreshStatistics(server: state.server)
                    }
                    return .merge(
                        .runGetDocuments(
                            filterRules: state.filter.input.filterRules,
                            server: state.server,
                            sortDirection: state.filter.input.sort.direction,
                            sortField: state.filter.input.sort.field
                        ),
                        .runRefreshStatistics(server: state.server)
                    )
                case let .onRowAppear(document):
                    if let nextPage = state.nextPage, state.documents.last?.id == document.id && !state.isLoadingMore {
                        state.error = nil
                        state.isLoadingMore = true
                        return .runGetMoreDocuments(
                            server: state.server,
                            url: nextPage
                        )
                    }
                    return .none
                case let .savedViewButtonTapped(savedView):
                    state.error = nil
                    state.filter.input = DocumentFilterInput(
                        filterRules: savedView.filterRules,
                        server: state.server,
                        sortDirection: savedView.sortDirection,
                        sortField: savedView.sortField
                    )
                    state.filter.savedView = savedView
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                case .scanButtonTapped:
                    return .send(.documentImport(.view(.scanButtonTapped)))
                case let .serverButtonTapped(server):
                    guard server != state.server else {
                        return .none
                    }
                    return .runSelectServer(server: server)
                case .toggleSelectionModeButtonTapped:
                    return .send(.documentSelection(.toggleSelectionModeButtonTapped(state.filter)))
                }
            case .binding, .delegate, .destination, .documentImport, .documentSelection, .documents, .path:
                return .none
            }
        }
        .forEach(\.documents, action: \.documents) { DocumentRowReducer() }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}

extension DocumentListReducer.Destination.State: Equatable {}
extension DocumentListReducer.Path.State: Equatable {}
