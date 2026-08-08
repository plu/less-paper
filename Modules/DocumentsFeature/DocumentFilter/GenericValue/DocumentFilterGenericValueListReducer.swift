import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentFilterGenericValueListReducer<Value: CustomStringConvertible & Equatable & Hashable & Identifiable &
    Sendable>: Sendable {
    public enum Action: BindableAction, Equatable, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case view(View)

        public enum View: Equatable {
            case closeButtonTapped
            case valueTapped(Value)
        }
    }

    public enum Delegate: Equatable {
        case filterUpdated(rule: DocumentFilterGenericValueRule, selection: Set<Value>)
    }

    @ObservableState
    public struct State: Equatable {

        var filteredValues: IdentifiedArrayOf<Value> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        var rule = DocumentFilterGenericValueRule.include

        var searchText = ""

        var selection: Set<Value> = []

        let values: IdentifiedArrayOf<Value>
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
                case let .valueTapped(value):
                    if state.selection.contains(value) {
                        state.selection.remove(value)
                    } else {
                        state.selection.insert(value)
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

extension DocumentFilterGenericValueListReducer.State where Value == Correspondent {
    static func testValue(
        rule: DocumentFilterGenericValueRule = .include,
        searchText: String = "",
        selection: Set<Value> = [],
        values: IdentifiedArrayOf<Correspondent> = []
    ) -> Self {
        .init(
            rule: rule,
            searchText: searchText,
            selection: selection,
            values: values
        )
    }
}

extension DocumentFilterGenericValueListReducer.State where Value == DocumentType {
    static func testValue(
        rule: DocumentFilterGenericValueRule = .include,
        searchText: String = "",
        selection: Set<Value> = [],
        values: IdentifiedArrayOf<DocumentType> = []
    ) -> Self {
        .init(
            rule: rule,
            searchText: searchText,
            selection: selection,
            values: values
        )
    }
}

extension DocumentFilterGenericValueListReducer.State where Value == StoragePath {
    static func testValue(
        rule: DocumentFilterGenericValueRule = .include,
        searchText: String = "",
        selection: Set<Value> = [],
        values: IdentifiedArrayOf<StoragePath> = []
    ) -> Self {
        .init(
            rule: rule,
            searchText: searchText,
            selection: selection,
            values: values
        )
    }
}
