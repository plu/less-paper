import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentTypeRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteDocumentType, name) else {
                return
            }
            await send(.delegate(.deleteDocumentType))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
