import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentTypeListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case isUpdating(id: DocumentType.Id, isUpdating: Bool)
        case getDocumentTypesResult([DocumentType])
        case documentTypeDeleted(DocumentType.Id)
        case documentTypes(IdentifiedActionOf<DocumentTypeRowReducer>)
        case view(View)

        public enum View {
            case createDocumentTypeButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case documentTypeForm(DocumentTypeFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        var searchText = ""

        var documentTypes: IdentifiedArrayOf<DocumentTypeRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visibleDocumentTypes: IdentifiedArrayOf<DocumentTypeRowReducer.State> {
            guard !searchText.isEmpty else {
                return documentTypes
            }
            return documentTypes.filter {
                $0.documentType.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        public init(
            documentTypes: IdentifiedArrayOf<DocumentTypeRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.documentTypes = documentTypes
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(documentType))))):
                state.destination = nil
                state.documentTypes.updateOrAppend(DocumentTypeRowReducer.State(documentType: documentType, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getDocumentTypesResult(documentTypes):
                state.documentTypes = IdentifiedArray(
                    uniqueElements: documentTypes.map {
                        DocumentTypeRowReducer.State(
                            documentType: $0,
                            server: state.server
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.documentTypes[id: id]?.isUpdating = isUpdating
                return .none
            case let .documentTypeDeleted(id):
                state.documentTypes.remove(id: id)
                return .none
            case let .documentTypes(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteDocumentType:
                    return .runDeleteDocumentType(
                        id: id,
                        server: state.server
                    )
                case .editDocumentType:
                    state.destination = .documentTypeForm(DocumentTypeFormReducer.State(
                        documentType: state.documentTypes[id: id]?.documentType,
                        server: state.server
                    ))
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .createDocumentTypeButtonTapped:
                    state.destination = .documentTypeForm(DocumentTypeFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetDocumentTypes(server: state.server)
                }
            case .binding, .destination, .documentTypes:
                return .none
            }
        }
        .forEach(\.documentTypes, action: \.documentTypes) { DocumentTypeRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.documentTypes.sort {
                $0.documentType.name.compare(
                    $1.documentType.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
            return .none
        }
    }

    public init() {}
}

extension DocumentTypeListReducer.Destination.State: Equatable {}
