import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import IdentifiedCollections

@Reducer
public struct CustomFieldQueryAtomEditorReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case documentPicker(PresentationAction<CustomFieldQueryDocumentPickerReducer.Action>)
        case error(Error)
        case linkedDocumentsLoaded(IdentifiedArrayOf<Document>)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            case atomChanged(CustomFieldQuery.Atom)
        }

        public enum View: Equatable {
            case closeButtonTapped
            case documentPickerTapped
            case fieldChanged(CustomField.Id)
            case onAppear
            case operatorChanged(CustomFieldQueryOperator)
            case optionToggled(String)
            case optionsDismissed
            case optionsTapped
            case valueChanged(JSONValue)
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        var atom: CustomFieldQuery.Atom

        @Presents
        var documentPicker: CustomFieldQueryDocumentPickerReducer.State?

        var isSelectingOptions = false

        let fields: IdentifiedArrayOf<CustomField>

        // Resolved titles for `linkedDocumentIds`, so the value capsule can name them. An id with
        // no entry here is a document that no longer exists and renders as its id.
        var linkedDocuments: IdentifiedArrayOf<Document> = []

        // The atom is addressed by path rather than bound into the tree: this sheet outlives a
        // delete of the row that opened it, and writing back through a stale path would land on
        // whatever moved into that index.
        let path: CustomFieldQuery.Path

        let server: Server

        public var id: CustomFieldQuery.Path {
            path
        }

        var field: CustomField? {
            fields[id: atom.field]
        }

        var selectedOptionIds: Set<String> {
            Set(atom.value.arrayValue?.compactMap(\.stringValue) ?? [])
        }

        var linkedDocumentIds: [Document.Id] {
            atom.value.arrayValue?
                .compactMap(\.intValue)
                .map(Document.Id.init(rawValue:)) ?? []
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .onAppear:
                    return .runResolveLinkedDocuments(state)
                case .documentPickerTapped:
                    state.documentPicker = .init(
                        selection: IdentifiedArray(uniqueElements: state.linkedDocuments),
                        server: state.server
                    )
                    return .none
                case let .fieldChanged(id):
                    guard let field = state.fields[id: id] else {
                        return .none
                    }
                    state.atom.setField(field)
                    return .send(.delegate(.atomChanged(state.atom)))
                case let .operatorChanged(queryOperator):
                    state.atom.setOperator(queryOperator, field: state.field)
                    return .send(.delegate(.atomChanged(state.atom)))
                case let .optionToggled(optionId):
                    var selected = state.selectedOptionIds
                    if selected.contains(optionId) {
                        selected.remove(optionId)
                    } else {
                        selected.insert(optionId)
                    }
                    // Sorted so the emitted rule is stable between openings of the sheet rather
                    // than following Set iteration order.
                    state.atom.value = .array(selected.sorted().map { .string($0) })
                    return .send(.delegate(.atomChanged(state.atom)))
                case .optionsDismissed:
                    state.isSelectingOptions = false
                    return .none
                case .optionsTapped:
                    state.isSelectingOptions = true
                    return .none
                case let .valueChanged(value):
                    state.atom.value = value
                    return .send(.delegate(.atomChanged(state.atom)))
                }
            case let .documentPicker(.presented(.delegate(.selectionChanged(ids)))):
                state.atom.value = .array(ids.map { .number(Double($0.rawValue)) })
                if let picker = state.documentPicker {
                    state.linkedDocuments = picker.selection
                }
                return .send(.delegate(.atomChanged(state.atom)))
            case let .error(error):
                return .toast(error)
            case let .linkedDocumentsLoaded(documents):
                state.linkedDocuments = documents
                return .none
            case .binding, .delegate, .documentPicker:
                return .none
            }
        }
        .ifLet(\.$documentPicker, action: \.documentPicker) {
            CustomFieldQueryDocumentPickerReducer()
        }
    }

    public init() {}
}
