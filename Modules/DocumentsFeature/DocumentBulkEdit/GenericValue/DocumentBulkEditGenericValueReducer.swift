import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentBulkEditGenericValueReducer<Value: DocumentBulkEditGenericValue>: Sendable {

    public enum Action: BindableAction, ViewAction {
        case applyConfirmed
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case selectionDataLoaded(GetSelectionDataOutput)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsUpdated
        }

        public enum View {
            case applyButtonTapped
            case closeButtonTapped
            case onAppear
            case resetButtonTapped
            case valueTapped(Value)
        }
    }

    public enum Operation: Equatable, Sendable {
        case assign(Value.ID)
        case remove
    }

    @ObservableState
    public struct State: Equatable {

        var documentCounts: [Value.ID: Int] = [:]

        let documents: Set<Document.Id>

        var confirmationMessage: LocalizedStringResource? {
            switch operation {
            case let .assign(id):
                guard let value = values[id: id] else {
                    return nil
                }
                return Value.confirmationAssign(name: value.description, documentCount: documents.count)
            case .remove:
                return Value.confirmationRemove(documentCount: documents.count)
            case nil:
                return nil
            }
        }

        var filteredValues: IdentifiedArrayOf<Value> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        var isEdited: Bool {
            operation != nil
        }

        var isLoading = false

        var isSaving = false

        var operation: Operation?

        var searchText = ""

        let server: Server

        let values: IdentifiedArrayOf<Value>

        func systemImage(for value: Value) -> String {
            switch operation {
            case let .assign(id):
                return id == value.id ? "checkmark.circle.fill" : "circle"
            case .remove:
                return "circle"
            case nil:
                let count = documentCounts[value.id] ?? 0
                if count == documents.count {
                    return "checkmark.circle.fill"
                }
                if count > 0 {
                    return "minus.circle"
                }
                return "circle"
            }
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .applyConfirmed:
                guard let operation = state.operation else {
                    return .none
                }
                state.isSaving = true
                return .runBulkEdit(
                    documents: state.documents,
                    id: {
                        if case let .assign(id) = operation {
                            return id
                        }
                        return nil
                    }(),
                    server: state.server
                )
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case let .selectionDataLoaded(output):
                state.documentCounts = Value.documentCounts(selectionData: output)
                state.isLoading = false
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .applyButtonTapped:
                    guard let message = state.confirmationMessage else {
                        return .none
                    }
                    return .runConfirmApply(message: message)
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
                    state.operation = nil
                    return .none
                case let .valueTapped(value):
                    let count = state.documentCounts[value.id] ?? 0
                    if state.operation == nil, count == state.documents.count {
                        state.operation = .remove
                    } else if case let .assign(id) = state.operation, id == value.id {
                        state.operation = .remove
                    } else {
                        state.operation = .assign(value.id)
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
