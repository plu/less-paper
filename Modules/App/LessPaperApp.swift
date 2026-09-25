import ApiImplementation
import ApiInterface
import AppFeature
import ComposableArchitecture
import ServersFeature
import SnapshotSupport
import SwiftUI

@main
struct LessPaperApp: App {

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }

    init() {
        // Before anything that could read the offline store. `@Shared(.offlineDocuments(server))`
        // is opened lazily by whichever state is built first, and a read that happens before the
        // move creates an empty file at the new path - which strands the user's documents at the
        // old one rather than failing in any way they could report.
        //
        // Being first in this body is only sufficient because `store` is a `static let`, so it is
        // not touched until `send(.bootstrap)` below. An instance property with a default value
        // would be initialised before this body runs, and the migration would be too late.
        OfflineStorageMigration.run()

        // Before the DEBUG overrides below, which replace this with an in-memory store: the share
        // extension writes the same keys, and two processes reading their own UserDefaults.standard
        // is two review cooldowns rather than one.
        prepareDependencies {
            $0.defaultAppStorage = .appGroup
        }
        #if DEBUG
        if let configuration = UITestConfiguration.fromEnvironment() {
            prepareUITestDependencies(configuration)
        }
        if let configuration = SnapshotConfiguration.fromEnvironment() {
            prepareSnapshotDependencies(configuration)
        }
        #endif
        Self.store.send(.bootstrap)
    }

    private static let store = Store(
        initialState: AppReducer.State(),
        reducer: { AppReducer() }
    )
}
