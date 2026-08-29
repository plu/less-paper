import ApiInterface
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct FavoriteRowReducer: Sendable {

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Document.Id { favorite.id }

        var favorite: FavoriteDocument
        let server: Server

        public init(favorite: FavoriteDocument, server: Server) {
            self.favorite = favorite
            self.server = server
        }
    }

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        @CasePathable
        public enum Delegate {
            case open(FavoriteDocument)
        }

        public enum View {
            case rowTapped
            case unfavoriteButtonTapped
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case .view(.rowTapped):
                return .send(.delegate(.open(state.favorite)))
            case .view(.unfavoriteButtonTapped):
                let id = state.id
                let server = state.server
                return .run { _ in
                    @Dependency(\.removeFavorite.execute) var removeFavorite
                    try await removeFavorite(id, server)
                }
            }
        }
    }

    public init() {}
}
