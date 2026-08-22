import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == StoragePathRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteStoragePath, name) else {
                return
            }
            await send(.delegate(.deleteStoragePath))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
