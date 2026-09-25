import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Tagged

@Reducer
public struct DocumentRowReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        case downloadFailed(Error)
        case downloadSucceeded(url: URL, intent: DownloadIntent)
        case favoriteToggleFailed(Error)
        case favoriteToggleSucceeded
        case inboxTagsCleared(tags: [Tag.Id])
        case inboxTagsFailed(Error)
        case view(View)

        public enum Delegate {
            case deleteDocument
            case inboxTagsCleared(tags: [Tag.Id])
            case presentDocumentDetail(Shared<Document>)
        }

        public enum View {
            case clearInboxTagsButtonTapped
            case deleteButtonTapped
            case editButtonTapped
            case favoriteButtonTapped
            case notesButtonTapped
            case previewButtonTapped
            case rowTapped
            case shareButtonTapped
            case viewButtonTapped(DocumentViewerSection)
        }
    }

    public enum DownloadIntent: Equatable, Sendable {
        case preview
        case share
    }

    @Reducer
    public enum Destination {
        case documentForm(DocumentFormReducer)
        case documentViewer(DocumentViewerReducer)
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Document.Id { document.id }

        var correspondent: String {
            document.correspondent?.get(server)?.name ?? "-"
        }

        @Presents
        var destination: Destination.State?

        @Shared
        var document: Document

        var documentType: String? {
            document.documentType?.get(server)?.name
        }

        var downloadedURL: URL?

        @SharedReader
        var favorites: IdentifiedArrayOf<OfflineDocument>

        var isBusy: Bool {
            isDownloading || isTogglingFavorite || isUpdating
        }

        @SharedReader
        var inboxTagIds: [Tag.Id]

        // The document's own tags that are inbox tags. Empty is what makes the swipe action hide
        // rather than clear nothing and report otherwise.
        var inboxTags: [Tag.Id] {
            document.tags.filter(Set(inboxTagIds).contains)
        }

        var isDownloading = false

        var isFavorited: Bool {
            favorites[id: document.id] != nil
        }

        var isTogglingFavorite = false

        var isUpdating = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeDocument) }

        var canDelete: Bool { permissions.can(.deleteDocument) }

        var canViewNotes: Bool { permissions.can(.viewNote) }

        var quickLookPreview: URL?

        var shareItem: ShareItem?

        var storagePath: String? {
            document.storagePath?.get(server)?.name
        }

        let server: Server

        var tags: [Tag] {
            document.tags.compactMap { $0.get(server) }
        }

        var titleLineLimit: Int {
            var titleLineLimit = 6
            if document.archiveSerialNumber != nil {
                titleLineLimit -= 1
            }
            if document.documentType != nil {
                titleLineLimit -= 1
            }
            if document.storagePath != nil {
                titleLineLimit -= 1
            }
            return titleLineLimit
        }

        public init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadedURL: URL? = nil,
            isDownloading: Bool = false,
            isTogglingFavorite: Bool = false,
            isUpdating: Bool = false,
            quickLookPreview: URL? = nil,
            server: Server,
            shareItem: ShareItem? = nil
        ) {
            self.destination = destination
            self._document = document
            self.downloadedURL = downloadedURL
            self._favorites = SharedReader(wrappedValue: [], .offlineDocuments(server))
            self._inboxTagIds = SharedReader(wrappedValue: [], .inboxTags(server))
            self.isDownloading = isDownloading
            self.isTogglingFavorite = isTogglingFavorite
            self.isUpdating = isUpdating
            self.quickLookPreview = quickLookPreview
            self.server = server
            self.shareItem = shareItem
            permissions = ServerPermissions(server: server)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
            case let .downloadFailed(error):
                state.isDownloading = false
                return .toast(error)
            case let .downloadSucceeded(url, intent):
                state.downloadedURL = url
                state.isDownloading = false
                state.present(url: url, intent: intent)
                return .none
            case let .favoriteToggleFailed(error):
                state.isTogglingFavorite = false
                return .toast(error)
            case .favoriteToggleSucceeded:
                state.isTogglingFavorite = false
                return .none
            case let .inboxTagsCleared(tags: tags):
                state.isUpdating = false
                // The undo toast and the restore belong to the list, not here. Clearing the tags is
                // what drops this row out of the inbox filter, and TCA cancels an element's effects
                // the moment its id leaves the array - so a toast awaited here is still on screen
                // when its Undo stops being connected to anything.
                return .send(.delegate(.inboxTagsCleared(tags: tags)))
            case let .inboxTagsFailed(error):
                state.isUpdating = false
                return .toast(error)
            case let .view(viewAction):
                switch viewAction {
                case .clearInboxTagsButtonTapped:
                    let tags = state.inboxTags
                    guard !tags.isEmpty else {
                        return .none
                    }
                    state.isUpdating = true
                    return .runClearInboxTags(
                        document: state.document.id,
                        tags: tags,
                        server: state.server
                    )
                case .deleteButtonTapped:
                    return .runConfirmDelete(documentTitle: state.document.title)
                case .editButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
                case .favoriteButtonTapped:
                    state.isTogglingFavorite = true
                    return .runToggleFavorite(
                        document: state.document,
                        isFavorited: state.isFavorited,
                        server: state.server
                    )
                case .notesButtonTapped:
                    // The form rather than the viewer: reaching for notes is usually reaching to
                    // add one, and the viewer can only show the ones already there.
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        section: .notes,
                        server: state.server
                    ))
                    return .none
                case .previewButtonTapped:
                    return state.download(intent: .preview)
                case .rowTapped:
                    return .send(.delegate(.presentDocumentDetail(state.$document)))
                case .shareButtonTapped:
                    return state.download(intent: .share)
                case let .viewButtonTapped(section):
                    state.destination = .documentViewer(DocumentViewerReducer.State(
                        document: state.$document,
                        section: section,
                        server: state.server
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

extension DocumentRowReducer.Action.Delegate: Equatable {}
extension DocumentRowReducer.Destination.State: Equatable {}
