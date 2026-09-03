@testable import ShareFeature

import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite(
    .dependencies {
        $0.copyFiles.execute = { $0 }
    }
)
struct DocumentImportReducerTests {

    @Test
    func test_view_importButtonTapped_presentsFileImporter() async throws {
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.importButtonTapped)) {
            $0.isPresentingFileImporter = true
        }
    }

    @Test
    func test_initialState_fileImporterNotPresented() async throws {
        let state = DocumentImportReducer.State()

        #expect(state.isPresentingFileImporter == false)
        #expect(state.isPresentingDocumentScanner == false)
        #expect(state.destination == nil)
    }

    @Test
    func test_view_scanButtonTapped_presentsDocumentScanner() async throws {
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.scanButtonTapped)) {
            $0.isPresentingDocumentScanner = true
        }
    }

    @Test
    func test_view_fileImporterResult_success_singleFile() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/test-document.pdf")
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.fileImporterResult(.success([testURL])))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files([testURL])
                )
            )
        }
    }

    @Test
    func test_view_fileImporterResult_success_multipleFiles() async throws {
        let testURLs = [
            URL(fileURLWithPath: "/tmp/document1.pdf"),
            URL(fileURLWithPath: "/tmp/document2.pdf"),
            URL(fileURLWithPath: "/tmp/document3.pdf"),
        ]
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.fileImporterResult(.success(testURLs)))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files(testURLs)
                )
            )
        }
    }

    @Test
    func test_view_fileImporterResult_success_emptyArray() async throws {
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.fileImporterResult(.success([])))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files([])
                )
            )
        }
    }

    @Test
    func test_view_fileImporterResult_failure_userCancelled() async throws {
        enum TestError: Error, Equatable {
            case userCancelled
        }

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.fileImporterResult(.failure(TestError.userCancelled))))

        #expect(store.state.destination == nil)
        #expect(toasts.value.count == 1)
    }

    @Test
    func test_view_fileImporterResult_failure_accessError() async throws {
        enum TestError: Error, Equatable {
            case accessDenied
        }

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.fileImporterResult(.failure(TestError.accessDenied))))

        #expect(store.state.destination == nil)
        #expect(toasts.value.count == 1)
    }

    @Test
    func test_view_fileImporterResult_failure_unknownError() async throws {
        enum TestError: Error, Equatable {
            case unknown
        }

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.fileImporterResult(.failure(TestError.unknown))))

        #expect(store.state.destination == nil)
        #expect(toasts.value.count == 1)
    }

    @Test
    func test_integration_completeImportWorkflow() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/invoice.pdf")
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.importButtonTapped)) {
            $0.isPresentingFileImporter = true
        }

        await store.send(.view(.fileImporterResult(.success([testURL])))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files([testURL])
                )
            )
        }

        #expect(store.state.destination?.shareExtension?.input == .files([testURL]))
    }

    @Test
    func test_integration_completeScanWorkflow() async throws {
        let scannedURL = URL(fileURLWithPath: "/tmp/scanned-document.pdf")
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.scanButtonTapped)) {
            $0.isPresentingDocumentScanner = true
        }

        await store.send(.view(.fileImporterResult(.success([scannedURL])))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files([scannedURL])
                )
            )
        }

        #expect(store.state.destination?.shareExtension?.input == .files([scannedURL]))
    }

    @Test
    func test_integration_importWorkflowWithError() async throws {
        enum TestError: Error, Equatable {
            case importFailed
        }

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.importButtonTapped)) {
            $0.isPresentingFileImporter = true
        }

        await store.send(.view(.fileImporterResult(.failure(TestError.importFailed))))

        #expect(store.state.destination == nil)
        #expect(store.state.isPresentingFileImporter == true)
        #expect(toasts.value.count == 1)
    }

    @Test
    func test_stateTransitions_independentPresentationFlags() async throws {
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.importButtonTapped)) {
            $0.isPresentingFileImporter = true
        }

        #expect(store.state.isPresentingFileImporter == true)
        #expect(store.state.isPresentingDocumentScanner == false)
    }

    @Test
    func test_stateTransitions_scannerPresentationFlag() async throws {
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.scanButtonTapped)) {
            $0.isPresentingDocumentScanner = true
        }

        #expect(store.state.isPresentingFileImporter == false)
        #expect(store.state.isPresentingDocumentScanner == true)
    }

    @Test
    func test_stateTransitions_destinationAfterSuccess() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/test.pdf")
        let store = TestStore(initialState: DocumentImportReducer.State()) {
            DocumentImportReducer()
        }

        await store.send(.view(.fileImporterResult(.success([testURL])))) {
            $0.destination = .shareExtension(
                ShareExtensionReducer.State(
                    input: .files([testURL])
                )
            )
        }

        guard case let .shareExtension(shareState) = store.state.destination else {
            Issue.record("Expected shareExtension destination")
            return
        }

        #expect(shareState.input == .files([testURL]))
    }

    // Getting paper in is what the app is for, so a finished import is the moment worth asking on.
    // It lives here rather than in the share screen itself because the share extension runs that
    // screen too, and an extension has no scene to ask in.
    @Test
    func shareExtensionImported_asksForAReview() async throws {
        let moments = LockIsolated<[ReviewMoment]>([])
        var initialState = DocumentImportReducer.State()
        initialState.destination = .shareExtension(.testValue())

        let store = TestStore(initialState: initialState) {
            DocumentImportReducer()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.reviewPrompt.record = { moment in moments.withValue { $0.append(moment) } }
        }

        await store.send(.destination(.presented(.shareExtension(.delegate(.imported)))))
        await store.finish()

        #expect(moments.value == [.documentImported])
    }
}
