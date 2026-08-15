import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import SavedViewsFeature
import StoragePathsFeature
import Tagged
import TagsFeature

@Reducer
public struct DocumentFilterReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case savedViewSaved(SavedView)
        case searchDebounced
        case view(View)

        @CasePathable
        public enum Delegate {
            case filterUpdated(DocumentFilter)
        }

        public enum View {
            case asnTypeButtonTapped(DocumentFilterASNType)
            case closeButtonTapped
            case correspondentButtonTapped
            case dateButtonTapped
            case documentTypeButtonTapped
            case resetButtonTapped
            case saveAsButtonTapped
            case saveButtonTapped
            case savedViewButtonTapped(SavedView?)
            case searchTypeButtonTapped(DocumentFilterSearchType)
            case searchValueChanged(String)
            case sortDirectionButtonTapped(SortDirection)
            case sortFieldButtonTapped(SortField)
            case storagePathButtonTapped
            case tagButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case correspondentList(DocumentFilterGenericValueListReducer<Correspondent>)
        case date(DocumentFilterDateReducer)
        case documentTypeList(DocumentFilterGenericValueListReducer<DocumentType>)
        case savedViewForm(SavedViewFormReducer)
        case storagePathList(DocumentFilterGenericValueListReducer<StoragePath>)
        case tagList(DocumentFilterTagListReducer)
    }

    @ObservableState
    public struct State: Equatable {
        @Presents
        var destination: Destination.State?

        var input: DocumentFilterInput

        var isModified: Bool {
            if let savedView {
                return [
                    savedView.filterRules.sorted() == input.filterRules.sorted(),
                    savedView.sortDirection == input.sort.direction,
                    savedView.sortField == input.sort.field
                ].contains(false)
            }
            return input != DocumentFilterInput()
        }

        var savedView: SavedView?

        let server: Server

        var sheetTitle: LocalizedStringResource {
            if let savedView {
                return .init(stringLiteral: savedView.name)
            }
            return .allDocuments
        }

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

        init(
            destination: DocumentFilterReducer.Destination.State? = nil,
            input: DocumentFilterInput = .init(),
            savedView: SavedView? = nil,
            server: Server
        ) {
            self.destination = destination
            self.input = input
            self.savedView = savedView
            self.server = server
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._savedViews = Shared(wrappedValue: [], .savedViews(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.correspondentList(.delegate(.filterUpdated(rule: rule, selection: selection))))):
                state.input.correspondent.rule = rule
                state.input.correspondent.selection = selection
                return .runFilterUpdated(state)
            case let .destination(.presented(.date(.delegate(.filterUpdated(date))))):
                state.input.date = date
                return .runFilterUpdated(state)
            case let .destination(.presented(.documentTypeList(.delegate(.filterUpdated(rule: rule, selection: selection))))):
                state.input.documentType.rule = rule
                state.input.documentType.selection = selection
                return .runFilterUpdated(state)
            case let .destination(.presented(.savedViewForm(.delegate(.savedViewSaved(savedView))))):
                state.destination = nil
                state.input = DocumentFilterInput(
                    filterRules: savedView.filterRules,
                    server: state.server,
                    sortDirection: savedView.sortDirection,
                    sortField: savedView.sortField
                )
                state.savedView = savedView
                return .runFilterUpdated(state)
            case let .destination(.presented(.storagePathList(.delegate(.filterUpdated(rule: rule, selection: selection))))):
                state.input.storagePath.rule = rule
                state.input.storagePath.selection = selection
                return .runFilterUpdated(state)
            case let .destination(.presented(.tagList(.delegate(.filterUpdated(rule: rule, selection))))):
                state.input.tag.rule = rule
                state.input.tag.selection = selection
                return .runFilterUpdated(state)
            case let .error(error):
                return .toast(error)
            case let .savedViewSaved(savedView):
                state.input = DocumentFilterInput(
                    filterRules: savedView.filterRules,
                    server: state.server,
                    sortDirection: savedView.sortDirection,
                    sortField: savedView.sortField
                )
                state.savedView = savedView
                return .runFilterUpdated(state)
            case .searchDebounced:
                return .runFilterUpdated(state)
            case let .view(viewAction):
                switch viewAction {
                case let .asnTypeButtonTapped(asnType):
                    state.input.asnType = asnType
                    state.input.searchType = .asn
                    return .runFilterUpdated(state)
                case .closeButtonTapped:
                    return .runDismiss()
                case .correspondentButtonTapped:
                    state.destination = .correspondentList(DocumentFilterGenericValueListReducer.State(
                        rule: state.input.correspondent.rule,
                        selection: state.input.correspondent.selection,
                        values: state.correspondents
                    ))
                    return .none
                case .dateButtonTapped:
                    state.destination = .date(DocumentFilterDateReducer.State(
                        date: state.input.date
                    ))
                    return .none
                case .documentTypeButtonTapped:
                    state.destination = .documentTypeList(DocumentFilterGenericValueListReducer.State(
                        rule: state.input.documentType.rule,
                        selection: state.input.documentType.selection,
                        values: state.documentTypes
                    ))
                    return .none
                case .resetButtonTapped:
                    state.input = DocumentFilterInput(
                        filterRules: state.savedView?.filterRules ?? [],
                        server: state.server,
                        sortDirection: state.savedView?.sortDirection ?? .descending,
                        sortField: state.savedView?.sortField ?? .added
                    )
                    return .runFilterUpdated(state)
                case .saveAsButtonTapped:
                    state.destination = .savedViewForm(SavedViewFormReducer.State(
                        input: SavedViewFormInput(filterRules: state.input.filterRules),
                        server: state.server
                    ))
                    return .none
                case .saveButtonTapped:
                    guard let savedView = state.savedView else {
                        return .none
                    }
                    return .runSaveView(
                        filterRules: state.input.filterRules,
                        savedView: savedView,
                        server: state.server,
                        sortDirection: state.input.sort.direction,
                        sortField: state.input.sort.field
                    )
                case let .savedViewButtonTapped(savedView):
                    state.input = DocumentFilterInput(
                        filterRules: savedView?.filterRules,
                        server: state.server,
                        sortDirection: savedView?.sortDirection,
                        sortField: savedView?.sortField
                    )
                    state.savedView = savedView
                    return .runFilterUpdated(state)
                case let .searchTypeButtonTapped(searchType):
                    state.input.searchType = searchType
                    return .runFilterUpdated(state)
                case let .searchValueChanged(searchValue):
                    // An explicit action rather than a binding: `$store.input.searchValue` is a
                    // chained lookup, so the store only ever sees `.binding(.set(\.input, …))` with
                    // the whole input — a `\.input.searchValue` case never matches, and a `\.input`
                    // one would silently catch every future binding on the sheet.
                    state.input.searchValue = searchValue
                    return .runSearchDebounce()
                case let .sortDirectionButtonTapped(direction):
                    state.input.sort.direction = direction
                    return .runFilterUpdated(state)
                case let .sortFieldButtonTapped(field):
                    state.input.sort.field = field
                    return .runFilterUpdated(state)
                case .storagePathButtonTapped:
                    state.destination = .storagePathList(DocumentFilterGenericValueListReducer.State(
                        rule: state.input.storagePath.rule,
                        selection: state.input.storagePath.selection,
                        values: state.storagePaths
                    ))
                    return .none
                case .tagButtonTapped:
                    state.destination = .tagList(DocumentFilterTagListReducer.State(
                        rule: state.input.tag.rule,
                        selection: state.input.tag.selection,
                        values: state.tags
                    ))
                    return .none
                }
            case .binding, .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DocumentFilterReducer.Destination.State: Equatable {}
