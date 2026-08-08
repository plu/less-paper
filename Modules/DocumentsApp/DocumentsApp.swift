import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import DocumentsFeature
import SwiftUI

@main
struct DocumentsApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                DocumentListView(
                    store: Self.store
                )
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
        initialState: DocumentListReducer.State(
            server: .testValue()
        ),
        reducer: {
            DocumentListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
