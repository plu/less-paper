import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == CorrespondentRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteCorrespondent, name) else {
                return
            }
            await send(.delegate(.deleteCorrespondent))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
