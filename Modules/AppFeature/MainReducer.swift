import ApiInterface
import ComposableArchitecture
import DocumentsFeature
import FavoritesFeature
import SettingsFeature

@Reducer
public struct MainReducer {

    public enum Action {
        case documentList(DocumentListReducer.Action)
        case favoriteList(FavoriteListReducer.Action)
        case inbox(DocumentListReducer.Action)
        case selectedTab(AppTab)
        case settingList(SettingListReducer.Action)
    }

    @ObservableState
    public struct State: Equatable {

        var documentList: DocumentListReducer.State

        var favoriteList: FavoriteListReducer.State

        var inbox: DocumentListReducer.State

        var selectedTab: AppTab

        let server: Server

        var settingList: SettingListReducer.State

        init(
            selectedTab: AppTab = .inbox,
            server: Server
        ) {
            self.documentList = .init(server: server)
            self.favoriteList = .init(server: server)
            self.inbox = .init(
                filter: .inbox(server: server),
                server: server
            )
            self.selectedTab = selectedTab
            self.server = server
            self.settingList = .init(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.documentList, action: \.documentList) {
            DocumentListReducer()
        }
        Scope(state: \.favoriteList, action: \.favoriteList) {
            FavoriteListReducer()
        }
        Scope(state: \.inbox, action: \.inbox) {
            DocumentListReducer()
        }
        Scope(state: \.settingList, action: \.settingList) {
            SettingListReducer()
        }
        Reduce { state, action in
            switch action {
            case let .documentList(.delegate(.documentsDeleted(ids))):
                return .send(.inbox(.documentsDeleted(ids)))
            case let .inbox(.delegate(.documentsDeleted(ids))):
                return .send(.documentList(.documentsDeleted(ids)))
            case let .selectedTab(tab):
                state.selectedTab = tab
                return .none
            case .documentList, .favoriteList, .inbox, .settingList:
                return .none
            }
        }
    }

    public init() {}
}
