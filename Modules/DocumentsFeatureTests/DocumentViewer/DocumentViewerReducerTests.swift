@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentViewerReducerTests {

    @Test
    func test_view_onAppear_writesFullDocumentIntoTheSharedValue() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let document = Shared(value: Document.testValue(content: "Some invoice"))
        let store = TestStore(initialState: DocumentViewerReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.hasLoadedContent = true
            $0.$document.withLock { $0 = full }
        }

        #expect(document.wrappedValue == full)
    }

    @Test
    func test_view_onAppear_failure_setsLoadErrorAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue()) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.receive(\.documentResult.failure) {
            $0.isLoadingDocument = false
            $0.loadError = ApiError.testValue().localizedDescription
        }

        #expect(store.state.hasLoadedContent == false)
        #expect(toasts.value.count == 1)

        // Re-appearing must not silently retry; only the retry button may.
        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_doesNotRefetchOnceLoaded() async throws {
        let calls = LockIsolated(0)
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue()) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in
                calls.withValue { $0 += 1 }
                return full
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)
        await store.send(.view(.onAppear))

        #expect(calls.value == 1)
    }

    @Test
    func test_view_retryLoadButtonTapped_afterFailure_refetches() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue(
            loadError: "The request timed out."
        )) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoadingDocument = true
            $0.loadError = nil
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.hasLoadedContent = true
            $0.$document.withLock { $0 = full }
        }
    }

    @Test
    func test_view_retryLoadButtonTapped_whileLoading_doesNotRefetch() async throws {
        let calls = LockIsolated(0)
        let gate = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue()) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in
                calls.withValue { $0 += 1 }
                await gate.stream.first { _ in true }
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.send(.view(.retryLoadButtonTapped))

        gate.continuation.yield()
        gate.continuation.finish()
        await store.receive(\.documentResult.success)

        #expect(calls.value == 1)
    }

    @Test
    func test_binding_section_doesNotRefetch() async throws {
        let calls = LockIsolated(0)
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue()) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in
                calls.withValue { $0 += 1 }
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.documentResult.success)
        await store.send(.binding(.set(\.section, .notes)))
        await store.send(.binding(.set(\.section, .content)))
        await store.send(.view(.onAppear))

        #expect(calls.value == 1)
    }

    @Test
    func test_metadata_loadsThroughTheScopedChild() async throws {
        let metadata = DocumentMetadata.testValue()
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue(
            section: .metadata
        )) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.getDocumentMetadata.execute = { _, _ in metadata }
        }

        await store.send(.metadata(.view(.onAppear))) {
            $0.metadata.isLoading = true
        }
        await store.receive(\.metadata.metadataResult) {
            $0.metadata.isLoading = false
            $0.metadata.metadata = metadata
        }
    }

    // The sheet scrolls the metadata card stack, but not the states that are centred in it.
    @Test
    func test_isContentScrollable_perSection() async throws {
        let loaded = DocumentViewerReducer.State.testValue(
            document: .testValue(content: "Some content"),
            hasLoadedContent: true,
            metadata: .testValue(),
            notes: [.testValue()],
            section: .metadata
        )

        #expect(loaded.isContentScrollable)

        var loading = DocumentViewerReducer.State.testValue(section: .metadata)
        #expect(!loading.isContentScrollable)

        loading.metadata.loadError = "The request timed out."
        #expect(!loading.isContentScrollable)

        var notes = loaded
        notes.section = .notes
        #expect(!notes.isContentScrollable)

        var content = loaded
        content.section = .content
        #expect(content.isContentScrollable)
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        let dismissCalls = LockIsolated(0)
        let store = TestStore(initialState: DocumentViewerReducer.State.testValue(
            hasLoadedContent: true
        )) {
            DocumentViewerReducer()
        } withDependencies: {
            $0.dismiss = .init {
                dismissCalls.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.closeButtonTapped))

        #expect(dismissCalls.value == 1)
    }

    // The whole document, not just its fields: presenting DocumentDetailReducer here works because
    // Swift permits the mutual recursion with its own Destination, which holds a viewer.
    @Test
    func openingALinkPresentsThatDocumentsDetail() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentViewerReducer.State.testValue(section: .customFields)
        ) {
            DocumentViewerReducer()
        }

        await store.send(.customFields(.delegate(.openDocument(linked)))) {
            $0.destination = .documentDetail(
                DocumentDetailReducer.State(document: Shared(value: linked), server: $0.server)
            )
        }
    }

    @Test
    func dismissingTheSheetClearsTheDestination() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentViewerReducer.State.testValue(section: .customFields)
        ) {
            DocumentViewerReducer()
        }

        await store.send(.customFields(.delegate(.openDocument(linked)))) {
            $0.destination = .documentDetail(
                DocumentDetailReducer.State(document: Shared(value: linked), server: $0.server)
            )
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    // The viewer is built from the list payload and replaces $document once the full document
    // arrives. The section shares that document rather than copying it at init, or fields the list
    // payload omitted would never appear.
    @Test
    func theSectionSeesFieldsThatArriveWithTheFullDocument() async throws {
        let store = TestStore(
            initialState: DocumentViewerReducer.State.testValue(
                document: .testValue(customFields: [], id: 1),
                section: .customFields
            )
        ) {
            DocumentViewerReducer()
        }
        store.exhaustivity = .off

        #expect(store.state.customFields.document.customFields.isEmpty)

        let full = Document.testValue(
            customFields: [.init(field: 3, value: .bool(true))],
            id: 1
        )
        await store.send(.documentResult(.success(full)))

        #expect(store.state.customFields.document.customFields.count == 1)
    }
}
