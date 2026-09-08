import Components
import ComposableArchitecture
import Intelligence

@Reducer
public struct DocumentTitleSuggestionsReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case generationFinished(TitleSuggestionError?)
        case suggestionsUpdated([String])
        case view(View)

        @CasePathable
        public enum Delegate {
            case titleSelected(String)
        }

        public enum View {
            case closeButtonTapped
            case onAppear
            case regenerateButtonTapped
            case retryButtonTapped
            case suggestionTapped(String)
        }
    }

    @ObservableState
    public struct State: Equatable {

        let context: TitleSuggestionContext

        var error: String?

        var isGenerating = false

        var suggestions: [String] = []

        init(context: TitleSuggestionContext) {
            self.context = context
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .generationFinished(error):
                state.isGenerating = false
                if let error {
                    state.error = message(for: error)
                } else if state.suggestions.isEmpty {
                    // Finishing with nothing yielded still has to land in the error branch: the
                    // view's ProgressView is gated on suggestions being empty, so leaving `error`
                    // nil here would show a spinner for work that has already stopped, with Retry
                    // unreachable because it lives in the error branch.
                    state.error = String(localized: .titleSuggestionFailed)
                }
                return .none
            case let .suggestionsUpdated(suggestions):
                state.suggestions = suggestions
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .onAppear:
                    guard state.suggestions.isEmpty, state.error == nil, !state.isGenerating else {
                        return .none
                    }
                    return start(&state)
                case .regenerateButtonTapped, .retryButtonTapped:
                    return start(&state)
                case let .suggestionTapped(title):
                    return .send(.delegate(.titleSelected(title)))
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    private func start(_ state: inout State) -> Effect<Action> {
        state.error = nil
        state.isGenerating = true
        // Cleared rather than left in place: rows are keyed by index, so a new stream filling into
        // a populated array would show a mix of the old titles and the new ones as it ran.
        state.suggestions = []
        return .runSuggest(context: state.context)
    }

    private func message(for error: TitleSuggestionError) -> String {
        switch error {
        case .contextWindowExceeded:
            String(localized: .titleSuggestionTooLong)
        case .guardrailViolation:
            String(localized: .titleSuggestionDeclined)
        case .failed, .unavailable:
            String(localized: .titleSuggestionFailed)
        }
    }
}
