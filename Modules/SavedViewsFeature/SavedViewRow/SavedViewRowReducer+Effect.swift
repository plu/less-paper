import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == SavedViewRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteSavedView, name) else {
                return
            }
            await send(.delegate(.deleteSavedView))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
