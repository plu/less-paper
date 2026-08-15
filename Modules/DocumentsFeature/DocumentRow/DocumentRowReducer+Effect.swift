import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentRowReducer.Action {

    /**
     * Asks the user to confirm deleting a document, and reports the answer upwards.
     *
     * The popup is presented by a dependency rather than held as navigation state so that the
     * effect stays suspended until the user answers — the same shape the bulk-edit confirmations
     * use.
     *
     * - Parameter documentTitle: The title shown in the confirmation message.
     */
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
