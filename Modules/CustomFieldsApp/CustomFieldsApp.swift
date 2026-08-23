import ApiImplementation
import ApiInterface
import ComposableArchitecture
import CustomFieldsFeature
import Dependencies
import SwiftUI

@main
struct CustomFieldsApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                NavigationStack {
                    CustomFieldListView(
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
        initialState: CustomFieldListReducer.State(
            server: .testValue()
        ),
        reducer: {
            CustomFieldListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
