import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentImportReducer {

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case view(View)

        public enum View {
            case fileImporterResult(Result<[URL], any Error>)
            case importButtonTapped
            case scanButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case shareExtension(ShareExtensionReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        public var destination: Destination.State?

        public var isPresentingDocumentScanner = false

        public var isPresentingFileImporter = false

        public init() {}
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case let .fileImporterResult(result):
                    switch result {
                    case let .failure(error):
                        return .toast(error)
                    case let .success(files):
                        state.destination = .shareExtension(
                            ShareExtensionReducer.State(
                                input: .files(files)
                            )
                        )
                        return .none
                    }
                case .importButtonTapped:
                    state.isPresentingFileImporter = true
                    return .none
                case .scanButtonTapped:
                    state.isPresentingDocumentScanner = true
                    return .none
                }
            case .binding, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}

extension DocumentImportReducer.Destination.State: Equatable {}
