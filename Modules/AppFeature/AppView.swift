import ComposableArchitecture
import ForwardAuthFeature
import ServersFeature
import SwiftUI

public struct AppView: View {

    public var body: some View {
        // Read here so @ObservableState registers this view as an observer of forwardAuth.sheet.
        // The Binding closures below are evaluated when SwiftUI queries the binding, not during
        // body evaluation, so a read only from inside them does not invalidate this view when
        // the state changes - and the sheet never re-checks isPresented.
        let sheetRedirect = store.forwardAuth.sheet

        return ZStack {
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
        // isPresented rather than item(:) because ForwardAuthRedirect.id is the server id, which
        // is the same across bounces of the same server - SwiftUI's item-based sheet would then
        // see the item as unchanged on the second bounce and refuse to re-present. isPresented
        // toggles false->true each time a new sign-in is requested.
        .sheet(
            isPresented: Binding(
                get: { sheetRedirect != nil },
                set: { isPresented in
                    if !isPresented, let redirect = sheetRedirect {
                        store.send(.forwardAuth(.signInCancelled(redirect)))
                    }
                }
            )
        ) {
            if let sheetRedirect {
                ForwardAuthSheetView(
                    redirect: sheetRedirect,
                    onFinished: { store.send(.forwardAuth(.signInFinished(sheetRedirect))) },
                    onCancel: { store.send(.forwardAuth(.signInCancelled(sheetRedirect))) }
                )
            }
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
