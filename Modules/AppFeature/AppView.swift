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
    }

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<AppReducer>
}
