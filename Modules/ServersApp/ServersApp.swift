import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import ServersFeature
import SwiftUI

@main
struct ServersApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ServerListView(
                    store: Self.store
                )
            }
        }
    }

    init() {
        prepareDependencies {
            $0.defaultAppStorage = .inMemory
            $0.defaultFileStorage = .inMemory
        }
    }

    private static let store = Store(
        initialState: ServerListReducer.State(),
        reducer: {
            ServerListReducer()
        }
    )
}
