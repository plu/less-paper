import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == PdfPasswordRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deletePdfPassword, name) else {
                return
            }
            await send(.delegate(.deletePdfPassword))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
