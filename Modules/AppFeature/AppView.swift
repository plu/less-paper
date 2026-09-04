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
            switch newPhase {
            case .active:
                store.send(.lifecyclePhaseChanged(.active))
                store.send(.didBecomeActive)
            case .background:
                store.send(.lifecyclePhaseChanged(.background))
            case .inactive:
                store.send(.lifecyclePhaseChanged(.inactive))
            @unknown default:
                break
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
