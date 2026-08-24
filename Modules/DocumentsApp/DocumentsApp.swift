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
                            // Negotiate first, as adding a server does in the real app. Without
                            // it every request carries the un-probed default, which a server
                            // outside that version answers 406 to.
                            _ = try await negotiateApiVersion(.testValue())
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

    @Dependency(\.negotiateApiVersion.execute)
    private var negotiateApiVersion

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
