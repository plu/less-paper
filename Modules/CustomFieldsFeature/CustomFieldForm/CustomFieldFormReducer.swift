import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct CustomFieldFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case view(View)

        @CasePathable
        public enum Delegate {
            case customFieldSaved(CustomField)
        }

        public enum View {
            case addOptionButtonTapped
            case cancelButtonTapped
            case closeButtonTapped
            case deleteOptionButtonTapped(id: UUID)
            case optionLabelChanged(id: UUID, label: String)
            case saveButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        public let customFieldId: CustomField.Id?

        public let server: Server

        public var input: CustomFieldFormInput

        public var isSaving = false

        // The server accepts a data_type change via PATCH, but changing the type of a field that
        // already holds values reinterprets or discards them and the app cannot undo that. So the
        // app refuses what the API allows.
        public var isDataTypeLocked: Bool {
            customFieldId != nil
        }

        public init(
            customField: CustomField? = nil,
            server: Server
        ) {
            self.customFieldId = customField?.id
            self.server = server
            input = CustomFieldFormInput(customField: customField)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .error(error):
                if let apiError = error as? ApiError, !apiError.fieldErrors.isEmpty {
                    state.input.applyFieldErrors(from: apiError)
                    return .toast(.error(String(localized: .formHasFieldErrors)))
                }
                return .toast(error)
            case let .view(viewAction):
                switch viewAction {
                case .addOptionButtonTapped:
                    let id = uuid()
                    state.input.selectOptions.append(
                        CustomFieldSelectOptionInput(
                            id: id,
                            label: "",
                            serverId: nil
                        )
                    )
                    state.input.focusedOptionId = id
                    return .none
                case .cancelButtonTapped, .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .deleteOptionButtonTapped(id):
                    state.input.selectOptions.remove(id: id)
                    if state.input.focusedOptionId == id {
                        state.input.focusedOptionId = nil
                    }
                    return .none
                case let .optionLabelChanged(id, label):
                    // A row that has just been removed can still deliver one last write as its
                    // field tears down; addressing options by id makes that a no-op rather than an
                    // out-of-range crash.
                    state.input.selectOptions[id: id]?.label = label
                    return .none
                case .saveButtonTapped:
                    return .runSaveCustomField(
                        id: state.customFieldId,
                        input: state.input.apiValue,
                        server: state.server
                    )
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}

    @Dependency(\.dismiss)
    private var dismiss

    @Dependency(\.uuid)
    private var uuid
}
