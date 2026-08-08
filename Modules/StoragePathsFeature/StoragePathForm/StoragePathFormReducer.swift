import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import PermissionsFeature
import SwiftUI

@Reducer
public struct StoragePathFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case permissionsForm(PermissionsFormReducer.Action)
        case view(View)

        @CasePathable
        public enum Delegate {
            case storagePathSaved(StoragePath)
        }

        public enum View {
            case cancelButtonTapped
            case closeButtonTapped
            case saveButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        public let storagePathId: StoragePath.Id?

        public let server: Server

        public var input: StoragePathFormInput

        public var isSaving = false

        public var permissionsForm: PermissionsFormReducer.State

        public init(
            storagePath: StoragePath? = nil,
            server: Server
        ) {
            self.storagePathId = storagePath?.id
            self.permissionsForm = .init(
                server: server,
                type: storagePath.ifPresent { .storagePath(id: $0.id) }
            )
            self.server = server
            input = StoragePathFormInput(storagePath: storagePath)
        }

        var section = StoragePathFormSection.form
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.permissionsForm, action: \.permissionsForm) {
            PermissionsFormReducer()
        }
        Reduce { state, action in
            switch action {
            case let .error(error):
                if let apiError = error as? ApiError, !apiError.fieldErrors.isEmpty {
                    state.input.applyFieldErrors(from: apiError)
                    return .toast(.error(String(localized: .formHasFieldErrors)))
                }
                return .toast(error)
            case let .permissionsForm(.delegate(.permissionsUpdated(update))):
                state.input.owner = update.owner?.map(\.id)
                state.input.setPermissions = update.permissions
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .cancelButtonTapped, .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case .saveButtonTapped:
                    return .runSaveStoragePath(
                        id: state.storagePathId,
                        input: state.input.apiValue,
                        server: state.server
                    )
                }
            case .binding, .delegate, .permissionsForm:
                return .none
            }
        }
    }

    public init() {}

    @Dependency(\.dismiss)
    private var dismiss
}
