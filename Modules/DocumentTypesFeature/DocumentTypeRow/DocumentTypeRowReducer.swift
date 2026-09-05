import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct DocumentTypeRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteDocumentType
            case editDocumentType
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: DocumentType.Id { documentType.id }

        let documentType: DocumentType

        var isUpdating = false

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        let server: Server

        init(
            isUpdating: Bool = false,
            server: Server,
            documentType: DocumentType
        ) {
            self.isUpdating = isUpdating
            self.server = server
            self.documentType = documentType
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editDocumentType))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.documentType.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
