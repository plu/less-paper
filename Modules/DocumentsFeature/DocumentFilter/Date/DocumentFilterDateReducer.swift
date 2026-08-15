import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentFilterDateReducer: Sendable {
    public enum Action: BindableAction, Equatable, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case view(View)

        public enum View: Equatable {
            case closeButtonTapped
            case fromButtonTapped
            case resetFromButtonTapped
            case resetToButtonTapped
            case toButtonTapped
        }
    }

    public enum Delegate: Equatable {
        case filterUpdated(DocumentFilterInput.DateFilter)
    }

    @ObservableState
    public struct State: Equatable {

        var date: DocumentFilterInput.DateFilter

        init(date: DocumentFilterInput.DateFilter = .init()) {
            self.date = date
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .send(.delegate(.filterUpdated(state.date)))
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .run { _ in
                        @Dependency(\.dismiss)
                        var dismiss

                        await dismiss()
                    }
                case .fromButtonTapped:
                    state.date.from.date = Date()
                    return .send(.delegate(.filterUpdated(state.date)))
                case .resetFromButtonTapped:
                    state.date.from = .init()
                    return .send(.delegate(.filterUpdated(state.date)))
                case .resetToButtonTapped:
                    state.date.to = .init()
                    return .send(.delegate(.filterUpdated(state.date)))
                case .toButtonTapped:
                    state.date.to.date = Date()
                    return .send(.delegate(.filterUpdated(state.date)))
                }
            case .delegate:
                return .none
            }
        }
    }

    public init() {}
}
