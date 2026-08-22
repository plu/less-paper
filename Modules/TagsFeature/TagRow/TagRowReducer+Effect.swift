import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == TagRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteTag, name) else {
                return
            }
            await send(.delegate(.deleteTag))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
