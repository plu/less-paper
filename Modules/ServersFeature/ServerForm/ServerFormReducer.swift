import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct ServerFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case mfaCodeRequired
        case view(View)

        @CasePathable
        public enum Delegate {
            case serverSaved(Server)
        }

        public enum View {
            case addHeaderButtonTapped
            case cancelButtonTapped
            case closeButtonTapped
            case deleteHeaderButtonTapped(HTTPHeader.ID)
            case headerNameChanged(HTTPHeader.ID, String)
            case headerValueChanged(HTTPHeader.ID, String)
            case saveButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case mfaForm(MfaFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        var destination: Destination.State?

        var input: ServerFormInput

        var isSaving = false

        var section = ServerFormSection.form

        public init(
            destination: Destination.State? = nil,
            input: ServerFormInput = .empty
        ) {
            self.destination = destination
            self.input = input
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.mfaForm(.delegate(delegateAction)))):
                switch delegateAction {
                case .cancel:
                    state.destination = nil
                    state.input.code = nil
                    state.isSaving = false
                    return .none
                case let .mfaCode(code):
                    state.destination = nil
                    state.input.code = code
                    return .runSaveServer(input: state.input)
                }
            case let .error(error):
                state.input.code = nil
                return .toast(error)
            case .mfaCodeRequired:
                state.destination = .mfaForm(MfaFormReducer.State())
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .addHeaderButtonTapped:
                    @Dependency(\.uuid)
                    var uuid

                    state.input.headers.append(HTTPHeader(id: uuid().uuidString, name: "", value: ""))
                    return .none
                case .cancelButtonTapped, .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .deleteHeaderButtonTapped(id):
                    state.input.headers.remove(id: id)
                    return .none
                case let .headerNameChanged(id, name):
                    state.input.headers[id: id]?.name = name
                    return .none
                case let .headerValueChanged(id, value):
                    state.input.headers[id: id]?.value = value
                    return .none
                case .saveButtonTapped:
                    return .runSaveServer(input: state.input)
                }
            case .binding, .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}

    @Dependency(\.dismiss)
    private var dismiss
}

extension ServerFormReducer.Destination.State: Equatable {}
