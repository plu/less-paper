import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentFilterTagListReducer: Sendable {
    public enum Action: BindableAction, Equatable, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case view(View)

        public enum View: Equatable {
            case closeButtonTapped
            case valueTapped(Tag)
        }
    }

    public enum Delegate: Equatable {
        case filterUpdated(
            rule: DocumentFilterTagRule,
            selection: DocumentFilterTagSelection
        )
    }

    @ObservableState
    public struct State: Equatable {

        var filteredValues: IdentifiedArrayOf<Tag> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        var rule = DocumentFilterTagRule.all

        var searchText = ""

        var selection = DocumentFilterTagSelection()

        let values: IdentifiedArrayOf<Tag>
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.rule):
                return .send(.delegate(.filterUpdated(
                    rule: state.rule,
                    selection: state.selection
                )))
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .run { _ in
                        @Dependency(\.dismiss)
                        var dismiss

                        await dismiss()
                    }
                case let .valueTapped(tag):
                    switch state.rule {
                    case .all:
                        if state.selection.all.include.contains(tag) {
                            state.selection.all.include.remove(tag)
                            state.selection.all.exclude.insert(tag)
                        } else if state.selection.all.exclude.contains(tag) {
                            state.selection.all.exclude.remove(tag)
                        } else {
                            state.selection.all.include.insert(tag)
                        }
                    case .any:
                        if state.selection.any.contains(tag) {
                            state.selection.any.remove(tag)
                        } else {
                            state.selection.any.insert(tag)
                        }
                    case .assigned, .notAssigned:
                        preconditionFailure()
                    }
                    return .send(.delegate(.filterUpdated(
                        rule: state.rule,
                        selection: state.selection
                    )))
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}

extension DocumentFilterTagListReducer.State {
    static func testValue(
        rule: DocumentFilterTagRule = .all,
        searchText: String = "",
        selection: DocumentFilterTagSelection = .testValue(),
        values: IdentifiedArrayOf<Tag> = []
    ) -> Self {
        .init(
            rule: rule,
            searchText: searchText,
            selection: selection,
            values: values
        )
    }
}
