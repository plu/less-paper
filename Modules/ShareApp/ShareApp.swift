import ApiImplementation
import ApiInterface
import ComposableArchitecture
import Dependencies
import ShareFeature
import SwiftSharing
import SwiftUI

@main
struct ShareApp: App {

    var body: some Scene {
        WindowGroup {
            VStack(spacing: .x5) {
                Button {
                    presentWithServer()
                } label: {
                    Text("With server")
                }
                .buttonStyle(.ghost())

                Button {
                    presentWithoutServer()
                } label: {
                    Text("Without server")
                }
                .buttonStyle(.ghost())

                Button {
                    presentWithoutContext()
                } label: {
                    Text("Without context")
                }
                .buttonStyle(.ghost())
            }
            .sheet(isPresented: $isPresented) {
                ShareExtensionView(
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
    }

    private func presentWithServer() {
        @Dependency(\.updateCache.execute)
        var updateCache

        @Shared(.selectedServer)
        var selectedServer: Server?

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $selectedServer.withLock { $0 = .testValue() }
        $servers.withLock {
            $0 = [
                .testValue(),
                .testValue(
                    alias: "CI",
                    id: "c0ff33",
                    url: .testValue()
                )
            ]
        }

        Task {
            try await updateCache(.testValue())
        }

        Self.store = StoreOf<ShareExtensionReducer>.testValue(
            extensionContext: TestExtensionContext.testValue(
                dismiss: { isPresented = false }
            )
        )

        isPresented = true
    }

    private func presentWithoutServer() {
        @Shared(.selectedServer)
        var selectedServer: Server?

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $selectedServer.withLock { $0 = nil }
        $servers.withLock { $0 = [] }

        Self.store = StoreOf<ShareExtensionReducer>.testValue(
            extensionContext: TestExtensionContext.testValue(
                dismiss: { isPresented = false }
            )
        )

        isPresented = true
    }

    private func presentWithoutContext() {
        @Shared(.selectedServer)
        var selectedServer: Server?

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        $selectedServer.withLock { $0 = .testValue() }
        $servers.withLock { $0 = [.testValue()] }

        Self.store = StoreOf<ShareExtensionReducer>.testValue(extensionContext: nil)

        isPresented = true
    }

    private static var store = StoreOf<ShareExtensionReducer>.testValue(extensionContext: nil)

    @State
    private var isPresented = false
}

private extension StoreOf<ShareExtensionReducer> {
    static func testValue(
        extensionContext: NSExtensionContext?
    ) -> StoreOf<ShareExtensionReducer> {
        Store(
            initialState: .testValue(
                input: .extensionContext(extensionContext)
            ),
            reducer: {
                ShareExtensionReducer()
            }
        )
    }
}
