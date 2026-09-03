import ApiInterface
import CertificatesFeature
import ComposableArchitecture
import Foundation
import SwiftSharing

public enum ShareExtensionError: Equatable {
    case importFailed(String?)
    case missingServer
}

@Reducer
public struct ShareExtensionReducer {

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case certificateApproval(CertificateApprovalReducer.Action)
        case delegate(Delegate)
        case error(Error)
        case filesLoaded([URL])
        case shareForm(ShareFormReducer.Action)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            // This screen runs in the share extension as well as in the app, and an extension has
            // no scene to show a review prompt in. Anything only the app can act on leaves as a
            // delegate rather than being done here.
            case imported
        }

        public enum View {
            case dismiss
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        var certificateApproval = CertificateApprovalReducer.State()

        var error: ShareExtensionError?

        var input: ShareExtensionInput

        var isLoading = false

        var shareForm: ShareFormReducer.State?

        @Shared(.selectedServer)
        var selectedServer: Server?

        public init(
            input: ShareExtensionInput
        ) {
            self.input = input
        }
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.certificateApproval, action: \.certificateApproval) {
            CertificateApprovalReducer()
        }
        Reduce { state, action in
            switch action {
            case let .error(error):
                state.error = .importFailed(error.localizedDescription)
                return .none
            case let .filesLoaded(files):
                guard !files.isEmpty else {
                    state.error = .importFailed(nil)
                    return .none
                }

                if let server = state.selectedServer {
                    state.shareForm = .init(
                        files: files,
                        server: server
                    )
                }
                return .none
            case let .shareForm(.delegate(.dismiss(didImport))):
                // Called exactly once: an extension context completes its request here, and asking
                // twice would complete it twice.
                let dismiss: Effect<Action> = state.input.dismiss() ? .none : .dismiss()
                guard didImport else {
                    return dismiss
                }
                return .send(.delegate(.imported)).merge(with: dismiss)
            case let .view(viewAction):
                switch viewAction {
                case .dismiss:
                    if state.input.dismiss() {
                        return .none
                    }
                    return .dismiss()
                case .onAppear:
                    if state.selectedServer == nil {
                        state.error = .missingServer
                        return .none
                    }
                    switch state.input {
                    case let .extensionContext(extensionContext):
                        guard let extensionContext else {
                            state.error = .importFailed(nil)
                            return .none
                        }
                        state.error = nil
                        return .runLoadItems(extensionContext: extensionContext)
                    case let .files(files):
                        state.error = nil
                        return .runLoadItems(files: files)
                    }
                }
            case .binding, .certificateApproval, .delegate, .shareForm:
                return .none
            }
        }

        .ifLet(\.shareForm, action: \.shareForm) {
            ShareFormReducer()
        }
    }

    public init() {}
}
