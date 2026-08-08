import ApiInterface
import AppFeature
import ComposableArchitecture
import ServersFeature
import SwiftUI

@main
struct LessPaperApp: App {

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }

    init() {
        Self.store.send(.bootstrap)
    }

    private static let store = Store(
        initialState: AppReducer.State(),
        reducer: { AppReducer() }
    )
}
