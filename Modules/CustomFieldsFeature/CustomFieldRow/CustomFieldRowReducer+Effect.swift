import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == CustomFieldRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteCustomField, name) else {
                return
            }
            await send(.delegate(.deleteCustomField))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
