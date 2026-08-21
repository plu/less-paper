import ApiInterface
import ComposableArchitecture
import Foundation

@Reducer
public struct PdfPasswordRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deletePdfPassword
        }

        public enum View {
            case deleteButtonTapped
            case revealButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: String { pdfPassword.id }

        var isRevealed = false

        let pdfPassword: PdfPassword

        public init(
            isRevealed: Bool = false,
            pdfPassword: PdfPassword
        ) {
            self.isRevealed = isRevealed
            self.pdfPassword = pdfPassword
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .deleteButtonTapped:
                    return .send(.delegate(.deletePdfPassword))
                case .revealButtonTapped:
                    state.isRevealed.toggle()
                    return .none
                }
            case .delegate:
                return .none
            }
        }
    }

    public init() {}
}
