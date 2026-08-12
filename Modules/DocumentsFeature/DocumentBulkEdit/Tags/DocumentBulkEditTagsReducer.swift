import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentBulkEditTagsReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case applyConfirmed
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case selectionDataLoaded(GetSelectionDataOutput)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsUpdated(Set<Document.Id>)
        }

        public enum View {
            case applyButtonTapped
            case closeButtonTapped
            case onAppear
            case resetButtonTapped
            case valueTapped(Tag)
        }
    }

    public enum Operation: Equatable, Sendable {
        case add
        case remove
    }

    @ObservableState
    public struct State: Equatable {

        var addTags: [Tag.Id] {
            operations.filter { $0.value == .add }.keys.sorted()
        }

        func confirmationTags(_ ids: [Tag.Id]) -> [Tag] {
            ids.compactMap { values[id: $0] }.sorted { $0.name < $1.name }
        }

        var documentCounts: [Tag.Id: Int] = [:]

        let documents: Set<Document.Id>

        var filteredValues: IdentifiedArrayOf<Tag> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        func isAssignedToAll(_ value: Tag) -> Bool {
            !documents.isEmpty && documentCounts[value.id, default: 0] == documents.count
        }

        func isAssignedToAny(_ value: Tag) -> Bool {
            documentCounts[value.id, default: 0] > 0
        }

        var isEdited: Bool {
            !operations.isEmpty
        }

        var isLoading = false

        var isSaving = false

        var operations: [Tag.Id: Operation] = [:]

        var removeTags: [Tag.Id] {
            operations.filter { $0.value == .remove }.keys.sorted()
        }

        var searchText = ""

        let server: Server

        func systemImage(for value: Tag) -> String {
            switch operations[value.id] {
            case .add:
                return "checkmark.circle.fill"
            case .remove:
                return "circle"
            case nil:
                if isAssignedToAll(value) {
                    return "checkmark.circle.fill"
                }
                if isAssignedToAny(value) {
                    return "minus.circle"
                }
                return "circle"
            }
        }

        let values: IdentifiedArrayOf<Tag>
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .applyConfirmed:
                guard state.isEdited else {
                    return .none
                }
                state.isSaving = true
                return .runBulkEdit(
                    addTags: state.addTags,
                    documents: state.documents,
                    removeTags: state.removeTags,
                    server: state.server
                )
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case let .selectionDataLoaded(output):
                state.documentCounts = Dictionary(
                    uniqueKeysWithValues: output.selectedTags.map { ($0.id, $0.documentCount) }
                )
                state.isLoading = false
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .applyButtonTapped:
                    guard state.isEdited else {
                        return .none
                    }
                    return .runConfirmApply(
                        addTags: state.confirmationTags(state.addTags),
                        documentCount: state.documents.count,
                        removeTags: state.confirmationTags(state.removeTags)
                    )
                case .closeButtonTapped:
                    return .run { _ in
                        @Dependency(\.dismiss)
                        var dismiss

                        await dismiss()
                    }
                case .onAppear:
                    state.isLoading = true
                    return .runGetSelectionData(
                        documents: state.documents,
                        server: state.server
                    )
                case .resetButtonTapped:
                    state.operations = [:]
                    return .none
                case let .valueTapped(value):
                    let isAssignedToAll = state.isAssignedToAll(value)
                    let isAssignedToAny = state.isAssignedToAny(value)
                    switch state.operations[value.id] {
                    case .remove where isAssignedToAll:
                        state.operations[value.id] = nil
                    case .add where isAssignedToAny:
                        state.operations[value.id] = .remove
                    case nil where isAssignedToAll:
                        state.operations[value.id] = .remove
                    case nil:
                        state.operations[value.id] = .add
                    default:
                        state.operations[value.id] = nil
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
