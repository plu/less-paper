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
            case editorDismissed
            case editorFieldChanged(CustomField.Id)
            case editorOperatorChanged(CustomFieldQueryOperator)
            case editorOptionToggled(String)
            case editorOptionsDismissed
            case editorOptionsTapped
            case editorValueChanged(JSONValue)
            case logicalOperatorTapped(CustomFieldQuery.Path, CustomFieldQueryLogicalOperator)
            case negationToggled(CustomFieldQuery.Path)
            case rowTapped(CustomFieldQuery.Path)
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {

        // The editor edits a copy addressed by path rather than a binding into the tree: the sheet
        // outlives a delete of the row that opened it, and writing back through a stale path would
        // land on whatever moved into that index.
        public struct Editor: Equatable, Identifiable, Sendable {
            var atom: CustomFieldQuery.Atom
            var isSelectingOptions = false
            let path: CustomFieldQuery.Path

            public var id: CustomFieldQuery.Path {
                path
            }
        }

        var editor: Editor?

        // The root is always a group so there is somewhere to add the first condition to. An
        // all-empty root serializes to nothing, which is what the server needs.
        var query: CustomFieldQuery

        let fields: IdentifiedArrayOf<CustomField>

        func children(at path: CustomFieldQuery.Path) -> [CustomFieldQuery] {
            query[path]?.children ?? []
        }

        func canAddCondition(at path: CustomFieldQuery.Path) -> Bool {
            !fields.isEmpty && query.atomCount < CustomFieldQuery.maximumAtoms
        }

        func canAddGroup(at path: CustomFieldQuery.Path) -> Bool {
            (path.count + 2) <= CustomFieldQuery.maximumDepth
        }

        init(
            editor: Editor? = nil,
            fields: IdentifiedArrayOf<CustomField>,
            query: CustomFieldQuery?
        ) {
            self.editor = editor
            self.fields = fields
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
                    state.editor = .init(atom: atom, path: path + [index])
                    return .none
                case let .addGroupTapped(path):
                    state.query.append(.group(.and, []), to: path)
                    return .none
                case .closeButtonTapped:
                    return .runDismiss()
                case let .deleteTapped(path):
                    state.query.remove(at: path)
                    return .send(.delegate(.filterUpdated(state.query.pruned)))
                case .editorDismissed:
                    state.editor = nil
                    return .send(.delegate(.filterUpdated(state.query.pruned)))
                case let .editorFieldChanged(id):
                    guard let field = state.fields[id: id] else {
                        return .none
                    }
                    state.editor?.atom.setField(field)
                    return .applyEditor(&state)
                case let .editorOperatorChanged(queryOperator):
                    guard let editor = state.editor else {
                        return .none
                    }
                    let field = state.fields[id: editor.atom.field]
                    state.editor?.atom.setOperator(queryOperator, field: field)
                    return .applyEditor(&state)
                case let .editorOptionToggled(optionId):
                    guard let editor = state.editor else {
                        return .none
                    }
                    var selected = Set(editor.atom.value.arrayValue?.compactMap(\.stringValue) ?? [])
                    if selected.contains(optionId) {
                        selected.remove(optionId)
                    } else {
                        selected.insert(optionId)
                    }
                    // Sorted so the emitted rule is stable between openings of the sheet rather
                    // than following Set iteration order.
                    let value = JSONValue.array(selected.sorted().map { .string($0) })
                    state.editor?.atom.value = value
                    return .applyEditor(&state)
                case .editorOptionsDismissed:
                    state.editor?.isSelectingOptions = false
                    return .none
                case .editorOptionsTapped:
                    state.editor?.isSelectingOptions = true
                    return .none
                case let .editorValueChanged(value):
                    state.editor?.atom.value = value
                    return .applyEditor(&state)
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
                        state.editor = .init(atom: atom, path: path)
                    case .group:
                        return .none
                    case let .negation(child):
                        // A negation is drawn as a modifier on the row it wraps, so tapping the
                        // row edits what is inside it rather than the wrapper.
                        guard case let .atom(atom) = child else {
                            return .none
                        }
                        state.editor = .init(atom: atom, path: path + [0])
                    case .none:
                        return .none
                    }
                    return .none
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}

private extension Effect where Action == CustomFieldQueryCardsReducer.Action {
    static func applyEditor(_ state: inout CustomFieldQueryCardsReducer.State) -> Self {
        guard let editor = state.editor else {
            return .none
        }
        state.query[editor.path] = .atom(editor.atom)
        return .send(.delegate(.filterUpdated(state.query.pruned)))
    }
}
