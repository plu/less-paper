import ComposableArchitecture
import ForwardAuthFeature
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
        .sheet(
            item: Binding(
                get: { store.forwardAuth.sheet },
                set: { newValue in
                    // A user-dismissed sheet still needs to release parked requests. Setting to
                    // nil here means the sheet is being torn down; the reducer clears state and
                    // sends .finish on the channel through .signInCancelled.
                    if newValue == nil, let redirect = store.forwardAuth.sheet {
                        store.send(.forwardAuth(.signInCancelled(redirect)))
                    }
                }
            )
        ) { redirect in
            ForwardAuthSheetView(
                redirect: redirect,
                onFinished: { store.send(.forwardAuth(.signInFinished(redirect))) },
                onCancel: { store.send(.forwardAuth(.signInCancelled(redirect))) }
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            store.send(.didBecomeActive)
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
