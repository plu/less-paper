import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import ShareFeature

@Reducer
public struct DocumentListReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case appendDocuments(GetDocumentsOutput)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case documentImport(DocumentImportReducer.Action)
        case documentSelection(DocumentSelectionReducer.Action)
        case documents(IdentifiedActionOf<DocumentRowReducer>)
        case error(Error)
        case path(StackActionOf<Path>)
        case replaceDocuments(GetDocumentsOutput)
        case view(View)

        public enum View {
            case allDocumentsButtonTapped
            case editCorrespondentButtonTapped
            case editDocumentTypeButtonTapped
            case editStoragePathButtonTapped
            case editTagsButtonTapped
            case filterButtonTapped
            case importButtonTapped
            case onAppear
            case onRefresh
            case onRowAppear(Document)
            case reloadButtonTapped
            case savedViewButtonTapped(SavedView)
            case scanButtonTapped
            case toggleSelectionModeButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>)
        case bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>)
        case bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>)
        case bulkEditTags(DocumentBulkEditTagsReducer)
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

        var documentTypes: IdentifiedArrayOf<DocumentType>

        @Shared

        var savedViews: IdentifiedArrayOf<SavedView>

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
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._savedViews = Shared(wrappedValue: [], .savedViews(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
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
                state.documents.append(contentsOf: output.results.map {
                    DocumentRowReducer.State(
                        document: $0,
                        server: state.server
                    )
                })
                state.documentSelection.allLoadedDocuments.formUnion(Set(output.results.map(\.id)))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
                return .none
            case .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated)))):
                state.destination = nil
                return .runGetDocuments(
                    filterRules: state.filter.input.filterRules,
                    server: state.server,
                    sortDirection: state.filter.input.sort.direction,
                    sortField: state.filter.input.sort.field
                )
            case let .destination(.presented(.documentFilter(.delegate(delegateAction)))):
                switch delegateAction {
                case let .filterUpdated(filter):
                    state.error = nil
                    state.filter = filter
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                }
            case let .documents(.element(id: _, action: .delegate(delegateAction))):
                switch delegateAction {
                case let .presentDocumentDetail(document):
                    state.path.append(.documentDetail(DocumentDetailReducer.State(
                        document: document,
                        server: state.server
                    )))
                    return .none
                }
            case let .error(error):
                state.error = error.localizedDescription
                return .toast(error)
            case let .path(.element(
                id: _,
                action: .documentDetail(.destination(.presented(.documentForm(.delegate(.documentUpdated(document))))))
            )):
                state.documents[id: document.id]?.document = document
                return .none
            case let .replaceDocuments(output):
                state.documents = IdentifiedArray(
                    uniqueElements: output.results.map {
                        DocumentRowReducer.State(
                            document: $0,
                            server: state.server
                        )
                    }
                )
                state.documentSelection.allLoadedDocuments = Set(output.results.map(\.id))
                state.nextPage = output.next
                state.totalNumberOfDocuments = output.count
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
                case .filterButtonTapped:
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
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
                case .onRefresh, .reloadButtonTapped:
                    state.error = nil
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
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
                case .toggleSelectionModeButtonTapped:
                    return .send(.documentSelection(.toggleSelectionModeButtonTapped(state.filter)))
                }
            case .binding, .destination, .documentImport, .documentSelection, .documents, .path:
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
