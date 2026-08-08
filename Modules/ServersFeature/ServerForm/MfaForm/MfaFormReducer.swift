import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct MfaFormReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case view(View)

        @CasePathable
        public enum Delegate {
            case cancel
            case mfaCode(String)
        }

        public enum View {
            case cancelButtonTapped
            case closeButtonTapped
            case submitButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {
        var mfaCode: String = ""
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .cancelButtonTapped, .closeButtonTapped:
                    return .send(.delegate(.cancel))
                case .submitButtonTapped:
                    return .send(.delegate(.mfaCode(state.mfaCode)))
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}
