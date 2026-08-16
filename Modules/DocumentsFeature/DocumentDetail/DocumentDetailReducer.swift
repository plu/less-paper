import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentDetailReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case downloadResult(DownloadResult)
        case view(View)

        public enum View {
            case editDocumentButtonTapped
            case onAppear
            case previewButtonTapped
            case retryDownloadButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case documentForm(DocumentFormReducer)
    }

    @ObservableState
    public struct State: Equatable {
        @Presents
        var destination: Destination.State?

        @Shared
        var document: Document

        var downloadResult: DownloadResult?

        var downloadedURL: URL? {
            downloadResult?.value?.url
        }

        var quickLookPreview: URL?

        let server: Server

        init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadResult: DownloadResult? = nil,
            quickLookPreview: URL? = nil,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.downloadResult = downloadResult
            self.quickLookPreview = quickLookPreview
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
            case let .downloadResult(result):
                state.downloadResult = result
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .editDocumentButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
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
