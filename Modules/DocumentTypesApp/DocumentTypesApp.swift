import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import DocumentTypesFeature
import SwiftUI

@main
struct DocumentTypesApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                NavigationStack {
                    DocumentTypeListView(
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
        initialState: DocumentTypeListReducer.State(
            server: .testValue()
        ),
        reducer: {
            DocumentTypeListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
