import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections

@Reducer
public struct DocumentShareLinksReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case createResult(Result<ShareLink, Error>)
        case delegate(Delegate)
        case deleteConfirmed(ShareLink.Id)
        case deleteResult(ShareLink.Id, Result<Void, Error>)
        case linksResult(Result<[ShareLink], Error>)
        case view(View)

        @CasePathable
        public enum Delegate {
            case close
        }

        public enum View {
            case closeButtonTapped
            case copyButtonTapped(ShareLink.Id)
            case createButtonTapped
            case deleteButtonTapped(ShareLink.Id)
            case onAppear
            case retryButtonTapped
        }
    }

    enum CancelID {
        case confirmDelete
        case create
        case delete
        case load
    }

    @ObservableState
    public struct State: Equatable {

        let documentId: Document.Id

        var expiry: DocumentShareLinksExpiry = .sevenDays

        let hasArchiveVersion: Bool

        var isCreating = false

        var isLoading = false

        // nil until the first load lands. A refused list leaves it nil, and the form must keep
        // working then: creating a link does not depend on being allowed to list them.
        var links: IdentifiedArrayOf<ShareLink>?

        var loadError: String?

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        let server: Server

        var shareArchiveVersion = true

        var shareItem: ShareItem?

        var canDelete: Bool { permissions.can(.deleteShareLink) }

        init(
            document: Document,
            server: Server
        ) {
            documentId = document.id
            hasArchiveVersion = document.archivedFileName != nil
            self.server = server
            permissions = ServerPermissions(server: server)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .createResult(result):
                state.isCreating = false
                switch result {
                case let .failure(error):
                    return .toast(error)
                case let .success(link):
                    state.links = state.links ?? []
                    state.links?.insert(link, at: 0)
                    state.shareItem = link.url(server: state.server).map(ShareItem.init)
                    return .none
                }
            case let .deleteConfirmed(id):
                return .runDeleteShareLink(id: id, server: state.server)
            case let .deleteResult(id, result):
                switch result {
                case let .failure(error):
                    return .toast(error)
                case .success:
                    state.links?.remove(id: id)
                    return .none
                }
            case let .linksResult(result):
                state.isLoading = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(links):
                    state.loadError = nil
                    // A create can land before the first list does; its link is not in that
                    // response and must not be dropped.
                    let loaded = IdentifiedArray(uniqueElements: links)
                    let created = state.links?.filter { loaded[id: $0.id] == nil } ?? []
                    state.links = IdentifiedArray(uniqueElements: created + loaded)
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .send(.delegate(.close))
                case let .copyButtonTapped(id):
                    guard let url = state.links?[id: id]?.url(server: state.server) else {
                        return .none
                    }
                    return .runCopy(url: url)
                case .createButtonTapped:
                    guard !state.isCreating else {
                        return .none
                    }
                    @Dependency(\.date.now)
                    var now

                    state.isCreating = true
                    return .runCreateShareLink(
                        input: CreateShareLinkInput(
                            document: state.documentId,
                            expiration: state.expiry.expiration(from: now),
                            // The toggle is only shown with an archive, and stays true in state
                            // when hidden, so the archive's existence has to gate it here.
                            fileVersion: state.hasArchiveVersion && state.shareArchiveVersion
                                ? .archive
                                : .original
                        ),
                        server: state.server
                    )
                case let .deleteButtonTapped(id):
                    guard state.canDelete, let link = state.links?[id: id] else {
                        return .none
                    }
                    return .runConfirmDelete(link: link)
                case .onAppear:
                    guard state.links == nil, state.loadError == nil, !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetShareLinks(documentId: state.documentId, server: state.server)
                case .retryButtonTapped:
                    guard !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    state.loadError = nil
                    return .runGetShareLinks(documentId: state.documentId, server: state.server)
                }
            case .binding, .delegate:
                return .none
            }
        }
    }
}
