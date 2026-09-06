import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentDetailReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case downloadResult(DownloadResult)
        case favoriteToggleFailed(Error)
        case favoriteToggleSucceeded
        case view(View)

        // The parent owns the collection this document belongs to, so it performs the deletion and
        // decides how to leave: this screen is showing a document that no longer exists.
        public enum Delegate {
            case deleteDocument(Document.Id)
        }

        public enum View {
            case deleteButtonTapped
            case editDocumentButtonTapped
            case favoriteButtonTapped
            case onAppear
            case previewButtonTapped
            case retryDownloadButtonTapped
            case viewButtonTapped(DocumentViewerSection)
        }
    }

    @Reducer
    public enum Destination {
        case documentForm(DocumentFormReducer)
        case documentViewer(DocumentViewerReducer)
    }

    @ObservableState
    public struct State: Equatable {
        @Presents
        var destination: Destination.State?

        // Public because whoever owns the stack this screen is pushed onto has to be able to see
        // which document it is showing: the Favorites tab pops it when that document stops being a
        // favorite.
        @Shared
        public var document: Document

        var downloadResult: DownloadResult?

        var downloadedURL: URL? {
            downloadResult?.value?.url
        }

        @SharedReader
        var favorites: IdentifiedArrayOf<FavoriteDocument>

        var isFavorited: Bool {
            favorites[id: document.id] != nil
        }

        // A favorite is a snapshot: it reads what was saved, and every user-initiated write the
        // detail path can otherwise reach — the edit form's save, its ASN lookup, its notes
        // composer and delete, its document picker — must stay unreachable, since none of those
        // dependencies are among the ones the Favorites tab overrides for reading.
        let isOfflineSnapshot: Bool

        var isTogglingFavorite = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeDocument) }

        var canDelete: Bool { permissions.can(.deleteDocument) }

        // The section, not a control inside it: without view_note the endpoint answers 403, so
        // there is nothing to show and nothing that could be added.
        var canViewNotes: Bool { permissions.can(.viewNote) }

        var quickLookPreview: URL?

        let server: Server

        public init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadResult: DownloadResult? = nil,
            isOfflineSnapshot: Bool = false,
            isTogglingFavorite: Bool = false,
            quickLookPreview: URL? = nil,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.downloadResult = downloadResult
            self._favorites = SharedReader(wrappedValue: [], .favorites(server))
            self.isOfflineSnapshot = isOfflineSnapshot
            self.isTogglingFavorite = isTogglingFavorite
            self.quickLookPreview = quickLookPreview
            self.server = server
            permissions = ServerPermissions(server: server)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            // The parent performs the deletion: it owns the collection this document belongs to,
            // and it is what decides whether this screen is popped or dismissed.
            case .delegate:
                return .none
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
            case let .downloadResult(result):
                state.downloadResult = result
                return .none
            case let .favoriteToggleFailed(error):
                state.isTogglingFavorite = false
                return .toast(error)
            case .favoriteToggleSucceeded:
                state.isTogglingFavorite = false
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .deleteButtonTapped:
                    // Same snapshot guard as the edit button below, for the same reason: a snapshot
                    // is read-only and this is a network write.
                    guard !state.isOfflineSnapshot else {
                        return .none
                    }
                    return .runConfirmDelete(documentTitle: state.document.title, id: state.document.id)
                case .editDocumentButtonTapped:
                    // A snapshot changes nothing: this stays unreachable even if something manages
                    // to send it with the edit button hidden, since it is the only door to the
                    // form's save, its ASN lookup, its notes composer and delete, and its picker.
                    guard !state.isOfflineSnapshot else {
                        return .none
                    }
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
                case .favoriteButtonTapped:
                    // Saving means SaveFavoriteUseCase's own reads run too, and a snapshot has
                    // those pinned to the record it already has — not to whatever this document
                    // turns out to be. Unfavoriting is fine: RemoveFavoriteUseCase touches none of
                    // the overridden dependencies. The view hides the button for the case this
                    // guards, so this is the belt to that braces.
                    guard !state.isOfflineSnapshot || state.isFavorited else {
                        return .none
                    }
                    state.isTogglingFavorite = true
                    return .runToggleFavorite(
                        document: state.document,
                        isFavorited: state.isFavorited,
                        server: state.server
                    )
                case .onAppear:
                    guard state.downloadResult == nil else {
                        return .none
                    }
                    return .runDownloadDocument(
                        document: state.document,
                        server: state.server
                    )
                case .previewButtonTapped:
                    state.quickLookPreview = state.downloadResult?.value?.url
                    return .none
                case let .viewButtonTapped(section):
                    state.destination = .documentViewer(DocumentViewerReducer.State(
                        document: state.$document,
                        isOfflineSnapshot: state.isOfflineSnapshot,
                        section: section,
                        server: state.server
                    ))
                    return .none
                case .retryDownloadButtonTapped:
                    state.downloadResult = nil
                    return .runDownloadDocument(
                        document: state.document,
                        server: state.server
                    )
                }
            case .binding, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DocumentDetailReducer.Destination.State: Equatable {}
