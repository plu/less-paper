import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections

@Reducer
public struct CustomFieldQueryCardsReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case editor(PresentationAction<CustomFieldQueryAtomEditorReducer.Action>)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            case filterUpdated(CustomFieldQuery?)
        }

        public enum View: Equatable {
            case addConditionTapped(CustomFieldQuery.Path)
            case addGroupTapped(CustomFieldQuery.Path)
            case closeButtonTapped
            case deleteTapped(CustomFieldQuery.Path)
            case logicalOperatorTapped(CustomFieldQuery.Path, CustomFieldQueryLogicalOperator)
            case negationToggled(CustomFieldQuery.Path)
            case rowTapped(CustomFieldQuery.Path)
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {

        @Presents
        var editor: CustomFieldQueryAtomEditorReducer.State?

        // The root is always a group so there is somewhere to add the first condition to. An
        // all-empty root serializes to nothing, which is what the server needs.
        var query: CustomFieldQuery

        let fields: IdentifiedArrayOf<CustomField>

        let server: Server

        func children(at path: CustomFieldQuery.Path) -> [CustomFieldQuery] {
            query[path]?.children ?? []
        }

        func makeEditor(
            atom: CustomFieldQuery.Atom,
            path: CustomFieldQuery.Path
        ) -> CustomFieldQueryAtomEditorReducer.State {
            .init(atom: atom, fields: fields, path: path, server: server)
        }

        func canAddCondition(at path: CustomFieldQuery.Path) -> Bool {
            !fields.isEmpty && query.atomCount < CustomFieldQuery.maximumAtoms
        }

        func canAddGroup(at path: CustomFieldQuery.Path) -> Bool {
            (path.count + 2) <= CustomFieldQuery.maximumDepth
        }

        init(
            editor: CustomFieldQueryAtomEditorReducer.State? = nil,
            fields: IdentifiedArrayOf<CustomField>,
            query: CustomFieldQuery?,
            server: Server
        ) {
            self.editor = editor
            self.fields = fields
            self.server = server
            // A bare atom loaded from a saved view is wrapped so the sheet always has a group to
            // add siblings to; `["AND",[atom]]` and a bare atom mean the same thing to the server.
            switch query {
            case let .group(logicalOperator, children):
                self.query = .group(logicalOperator, children)
            case let .some(other):
                self.query = .group(.and, [other])
            case .none:
                self.query = .group(.and, [])
            }
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .editor(.presented(.delegate(.atomChanged(atom)))):
                guard let path = state.editor?.path else {
                    return .none
                }
                state.query[path] = .atom(atom)
                return .send(.delegate(.filterUpdated(state.query.pruned)))
            case let .view(viewAction):
                switch viewAction {
                case let .addConditionTapped(path):
                    guard let field = state.fields.first,
                          let atom = CustomFieldQuery.Atom(defaultFor: field)
                    else {
                        return .none
                    }
                    state.query.append(.atom(atom), to: path)
                    let index = max((state.query[path]?.children?.count ?? 1) - 1, 0)
                    state.editor = state.makeEditor(atom: atom, path: path + [index])
                    return .none
                case let .addGroupTapped(path):
                    state.query.append(.group(.and, []), to: path)
                    return .none
                case .closeButtonTapped:
                    return .runDismiss()
                case let .deleteTapped(path):
                    state.query.remove(at: path)
                    return .send(.delegate(.filterUpdated(state.query.pruned)))
                case let .logicalOperatorTapped(path, logicalOperator):
                    guard let children = state.query[path]?.children else {
                        return .none
                    }
                    state.query[path] = .group(logicalOperator, children)
                    return .send(.delegate(.filterUpdated(state.query.pruned)))
                case let .negationToggled(path):
                    guard let node = state.query[path] else {
                        return .none
                    }
                    if case let .negation(child) = node {
                        state.query[path] = child
                    } else {
                        state.query[path] = .negation(node)
                    }
                    return .send(.delegate(.filterUpdated(state.query.pruned)))
                case let .rowTapped(path):
                    switch state.query[path] {
                    case let .atom(atom):
                        state.editor = state.makeEditor(atom: atom, path: path)
                    case .group:
                        return .none
                    case let .negation(child):
                        // A negation is drawn as a modifier on the row it wraps, so tapping the
                        // row edits what is inside it rather than the wrapper.
                        guard case let .atom(atom) = child else {
                            return .none
                        }
                        state.editor = state.makeEditor(atom: atom, path: path + [0])
                    case .none:
                        return .none
                    }
                    return .none
                }
            case .binding, .delegate, .editor:
                return .none
            }
        }
        .ifLet(\.$editor, action: \.editor) {
            CustomFieldQueryAtomEditorReducer()
        }
    }

    public init() {}
}
