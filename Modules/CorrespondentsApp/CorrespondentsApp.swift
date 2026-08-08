import ApiImplementation
import ApiInterface
import ComposableArchitecture
import CorrespondentsFeature
import Dependencies
import SwiftUI

@main
struct CorrespondentsApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                NavigationStack {
                    CorrespondentListView(
                        store: Self.store
                    )
                }
            } else {
                ProgressView()
                    .task {
                        do {
                            try await updateCache(.testValue())
                            isInitialised = true
                        } catch {
                            debugPrint(error)
                        }
                    }
            }
        }
    }

    init() {
        prepareDependencies {
            $0.authenticationProvider = .integrationTest
            $0.defaultAppStorage = .inMemory
            $0.defaultFileStorage = .inMemory
        }
    }

    private static let store = Store(
        initialState: CorrespondentListReducer.State(
            server: .testValue()
        ),
        reducer: {
            CorrespondentListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
