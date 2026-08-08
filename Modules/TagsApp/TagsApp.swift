import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import SwiftUI
import TagsFeature

@main
struct TagsApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                NavigationStack {
                    TagListView(
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
        initialState: TagListReducer.State(
            server: .testValue()
        ),
        reducer: {
            TagListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
