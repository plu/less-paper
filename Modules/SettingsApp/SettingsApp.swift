import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import SettingsFeature
import SwiftUI

@main
struct SettingsApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SettingListView(
                    store: Self.store
                )
            }
        }
    }

    init() {
        prepareDependencies {
            $0.authenticationProvider = .integrationTest
            $0.defaultAppStorage = .inMemory
            $0.defaultFileStorage = .inMemory
        }

        @Shared(.selectedServer)
        var selectedServer: Server?

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $selectedServer.withLock { $0 = .testValue() }
        $servers.withLock { $0 = [.testValue()] }
    }

    private static let store = Store(
        initialState: .testValue(),
        reducer: {
            SettingListReducer()
        }
    )
}
