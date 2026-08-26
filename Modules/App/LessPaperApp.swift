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
