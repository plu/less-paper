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
        case view(View)

        public enum Delegate {
            case deleteDocument
            case presentDocumentDetail(Shared<Document>)
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
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

        var isBusy: Bool {
            isDownloading || isUpdating
        }

        var isDownloading = false

        var isUpdating = false

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

        init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadedURL: URL? = nil,
            isDownloading: Bool = false,
            isUpdating: Bool = false,
            quickLookPreview: URL? = nil,
            server: Server,
            shareItem: ShareItem? = nil
        ) {
            self.destination = destination
            self._document = document
            self.downloadedURL = downloadedURL
            self.isDownloading = isDownloading
            self.isUpdating = isUpdating
            self.quickLookPreview = quickLookPreview
            self.server = server
            self.shareItem = shareItem
        }
    }

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
            case let .view(viewAction):
                switch viewAction {
                case .deleteButtonTapped:
                    return .runConfirmDelete(documentTitle: state.document.title)
                case .editButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
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
