import ApiInterface
import CertificatesFeature
import ComposableArchitecture
import Foundation
import SwiftSharing

public enum ShareExtensionError: Equatable {
    case importFailed(String?)
    // Not a failure, and the one place this app explains a permission. Everywhere else a control
    // the user cannot use is simply absent, because the app can hide its own entrances. iOS owns
    // this one: the share sheet opens whatever we think, and without add_document every screen
    // behind it is dead, so the alternative is a sheet offering nothing but Skip.
    case importNotPermitted(serverAlias: String)
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

        // Read for the import permission check only: the sheet is blocked outright when no
        // configured server can add documents, and left alone when switching to another would
        // help. ShareFormReducer holds the same list to drive its picker.
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

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
                    guard let selectedServer = state.selectedServer else {
                        state.error = .missingServer
                        return .none
                    }
                    // Only when NOTHING can be imported anywhere. Blocking on the SELECTED server
                    // alone traps a multi-server user: the server picker lives inside the form
                    // this replaces, so the one control that could fix the problem disappears with
                    // it. When another server would work, the form renders and ShareFormView shows
                    // the explanation beside its own Skip button instead.
                    //
                    // Fails open like every other gate - an unread cache answers true, so a server
                    // whose permissions were never fetched counts as able to import.
                    // `!isEmpty` first, and not defensively: allSatisfy is vacuously true on an
                    // empty list, so without it a state with no server list would block the sheet
                    // outright. No list means nothing is known, and nothing known fails open.
                    let noServerCanImport = !state.servers.isEmpty && state.servers.allSatisfy {
                        !ServerPermissions(server: $0).can(.addDocument)
                    }
                    if noServerCanImport {
                        state.error = .importNotPermitted(serverAlias: selectedServer.alias)
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
