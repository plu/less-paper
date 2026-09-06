import ComposableArchitecture
import ServersFeature
import SwiftUI

public struct AppView: View {

    public var body: some View {
        ZStack {
            if let store = store.scope(state: \.main, action: \.main) {
                MainView(store: store)
                    .id(store.server.id)
            } else {
                NavigationStack {
                    ServerListView(
                        store: store.scope(
                            state: \.serverList,
                            action: \.serverList
                        )
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Only becoming active matters: it is what refreshes permissions and favourites. The
            // other phases were observed solely to log them, which said nothing a reader of a
            // shared log could act on.
            if newPhase == .active {
                store.send(.didBecomeActive)
            }
        }
        .onOpenURL { url in
            store.send(.openURL(url))
        }
    }

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<AppReducer>

    @Environment(\.scenePhase)
    private var scenePhase
}
