import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentRowReducer.Action {

    static func runConfirmDelete(documentTitle: String) -> Self {
        @Dependency(\.documentDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentTitle) else {
                return
            }
            await send(.delegate(.deleteDocument))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
