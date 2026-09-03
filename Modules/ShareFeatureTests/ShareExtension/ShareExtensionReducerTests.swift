@testable import ShareFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies {
        $0.copyFiles.execute = { $0 }
    }
)
struct ShareExtensionReducerTests {

    @Test
    func test_view_onAppear_missingServer() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server?

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(nil)
        )) {
            ShareExtensionReducer()
        }

        await store.send(.view(.onAppear)) {
            $0.error = .missingServer
        }
    }

    @Test
    func test_view_onAppear_missingContext() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(nil)
        )) {
            ShareExtensionReducer()
        }

        await store.send(.view(.onAppear)) {
            $0.error = .importFailed(nil)
        }
    }

    @Test
    func test_view_onAppear_emptyFiles() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let extensionContext = TestExtensionContext.testValue(fileNames: [])

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(extensionContext)
        )) {
            ShareExtensionReducer()
        }

        let bootstrap = await store.send(.view(.onAppear))
        await store.receive(\.certificateApproval.bootstrap)
        await store.receive(\.binding, .set(\.isLoading, true))
        await store.receive(\.filesLoaded, []) {
            $0.error = .importFailed(nil)
        }
        await store.receive(\.binding, .set(\.isLoading, false))
        await bootstrap.cancel()
    }

    @Test
    func test_view_onAppear_copyFilesFailure() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let extensionContext = TestExtensionContext.testValue(fileNames: [])

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(extensionContext)
        )) {
            ShareExtensionReducer()
        } withDependencies: {
            $0.copyFiles.execute = { _ in throw TestError.someError }
        }

        let bootstrap = await store.send(.view(.onAppear))
        await store.receive(\.certificateApproval.bootstrap)
        await store.receive(\.binding, .set(\.isLoading, true))
        await store.receive(\.error) {
            $0.error = .importFailed("TestError.someError")
        }
        await store.receive(\.binding, .set(\.isLoading, false))
        await bootstrap.cancel()
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let extensionContext = TestExtensionContext.testValue()
        let expectedFiles = [
            URL.testPDF(named: "Puky.pdf"),
            URL.testPDF(named: "Puky-Locked.pdf"),
            URL.testPDF(named: "TonieBox.pdf"),
        ]

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(extensionContext)
        )) {
            ShareExtensionReducer()
        }

        let bootstrap = await store.send(.view(.onAppear))
        await store.receive(\.certificateApproval.bootstrap)
        await store.receive(\.binding, .set(\.isLoading, true))
        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.receive(\.filesLoaded, expectedFiles)
        }
        await store.receive(\.binding, .set(\.isLoading, false))
        await bootstrap.cancel()
    }

    @Test
    func test_view_onAppear_files_success() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let files: [URL] = [
            .testPDF(named: "Puky.pdf"),
            .testPDF(named: "Puky-Locked.pdf"),
            .testPDF(named: "TonieBox.pdf"),
        ]

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .files(files)
        )) {
            ShareExtensionReducer()
        }

        let bootstrap = await store.send(.view(.onAppear))
        await store.receive(\.certificateApproval.bootstrap)
        await store.receive(\.binding, .set(\.isLoading, true))
        await store.withExhaustivity(.off(showSkippedAssertions: false)) {
            await store.receive(\.filesLoaded, files)
        }
        await store.receive(\.binding, .set(\.isLoading, false))
        await bootstrap.cancel()
    }

    @Test
    func test_view_dismiss() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server? = .testValue()
        let dismissed = LockIsolated(false)
        let extensionContext = TestExtensionContext.testValue(
            dismiss: { dismissed.setValue(true) }
        )

        let store = TestStore(initialState: ShareExtensionReducer.State.testValue(
            input: .extensionContext(extensionContext)
        )) {
            ShareExtensionReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.onAppear))
        await store.send(.view(.dismiss))

        #expect(dismissed.value == true)
    }

    // The app wraps this screen and the share extension does not, so anything that only the app
    // can act on - asking for a review, here - has to leave as a delegate rather than be done in
    // place.
    @Test
    func shareFormDismissed_afterAnImport_tellsTheParent() async throws {
        let store = TestStore(initialState: Self.dismissableState()) {
            ShareExtensionReducer()
        }

        await store.send(.shareForm(.delegate(.dismiss(didImport: true))))
        await store.receive(\.delegate, .imported)
    }

    @Test
    func shareFormDismissed_withoutAnImport_tellsTheParentNothing() async throws {
        let store = TestStore(initialState: Self.dismissableState()) {
            ShareExtensionReducer()
        }

        await store.send(.shareForm(.delegate(.dismiss(didImport: false))))
    }

    // An extension context dismisses itself, which keeps the TCA dismiss effect - and the
    // "dismissed something that was never presented" warning it raises in a store with no parent -
    // out of the way of what these two are asserting.
    private static func dismissableState() -> ShareExtensionReducer.State {
        var state = ShareExtensionReducer.State.testValue(
            input: .extensionContext(TestExtensionContext.testValue())
        )
        state.shareForm = .testValue()
        return state
    }
}
