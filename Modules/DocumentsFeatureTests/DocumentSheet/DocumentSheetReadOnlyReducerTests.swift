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
    .testDependencies()
)
struct DocumentSheetReadOnlyReducerTests {

    @Test
    func test_view_onAppear_writesFullDocumentIntoTheSharedValue() async throws {
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let document = Shared(value: Document.testValue(content: "Some invoice"))
        let store = TestStore(initialState: DocumentSheetReducer.State(
            document: document,
            server: .testValue()
        )) {
            DocumentSheetReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoadingDocument = true
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.content = full.content
            $0.$document.withLock { $0 = full }
        }

        #expect(document.wrappedValue == full)
    }

    @Test
    func test_view_onAppear_failure_setsLoadErrorAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue()) {
            DocumentSheetReducer()
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

        #expect(store.state.content == nil)
        #expect(toasts.value.count == 1)

        // Re-appearing must not silently retry; only the retry button may.
        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_doesNotRefetchOnceLoaded() async throws {
        let calls = LockIsolated(0)
        let full = Document.testValue(content: "Some invoice, and all the rest of the OCR text")
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue()) {
            DocumentSheetReducer()
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
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue(
            loadError: "The request timed out."
        )) {
            DocumentSheetReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in full }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoadingDocument = true
            $0.loadError = nil
        }
        await store.receive(\.documentResult.success, full) {
            $0.isLoadingDocument = false
            $0.content = full.content
            $0.$document.withLock { $0 = full }
        }
    }

    @Test
    func test_view_retryLoadButtonTapped_whileLoading_doesNotRefetch() async throws {
        let calls = LockIsolated(0)
        let gate = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue()) {
            DocumentSheetReducer()
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
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue()) {
            DocumentSheetReducer()
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
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue(
            section: .metadata
        )) {
            DocumentSheetReducer()
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
    func test_isSheetScrollable_perSection() async throws {
        let loaded = DocumentSheetReducer.State.testValue(
            content: "Some content",
            isOfflineSnapshot: true,
            metadata: .testValue(),
            notes: [.testValue()],
            section: .metadata
        )

        #expect(loaded.isSheetScrollable)

        var loading = DocumentSheetReducer.State.testValue(section: .metadata)
        #expect(!loading.isSheetScrollable)

        loading.metadata.loadError = "The request timed out."
        #expect(!loading.isSheetScrollable)

        var notes = loaded
        notes.section = .notes
        #expect(!notes.isSheetScrollable)

        var history = loaded
        history.section = .history
        #expect(!history.isSheetScrollable)

        var content = loaded
        content.section = .content
        #expect(content.isSheetScrollable)
    }

    // Editable content is a TextEditor, which scrolls itself; the sheet scrolling around it would
    // fight it for the gesture.
    @Test
    func test_isSheetScrollable_editableContentScrollsItself() async throws {
        let state = DocumentSheetReducer.State.testValue(content: "Some content", section: .content)

        #expect(state.isEditable)
        #expect(!state.isSheetScrollable)
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        let dismissCalls = LockIsolated(0)
        let store = TestStore(initialState: DocumentSheetReducer.State.testValue(
            content: "Some content"
        )) {
            DocumentSheetReducer()
        } withDependencies: {
            $0.dismiss = .init {
                dismissCalls.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.closeButtonTapped))

        #expect(dismissCalls.value == 1)
    }

    // The whole document, not just its fields: presenting DocumentDetailReducer here works because
    // Swift permits the mutual recursion with its own Destination, which holds this sheet.
    @Test
    func openingALinkPresentsThatDocumentsDetail() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentSheetReducer.State.testValue(section: .customFields)
        ) {
            DocumentSheetReducer()
        }

        await store.send(.readOnlyCustomFields(.delegate(.openDocument(linked)))) {
            $0.destination = .documentDetail(
                DocumentDetailReducer.State(document: Shared(value: linked), server: $0.server)
            )
        }
    }

    // A sheet opened from an offline document's detail is itself a snapshot, and a linked document
    // reached through it is not the document the Offline tab already vouched for — its own edits
    // must stay just as unreachable.
    @Test
    func openingALinkFromAnOfflineSnapshotCarriesTheFlagIntoTheLinkedDetail() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentSheetReducer.State.testValue(
                isOfflineSnapshot: true,
                section: .customFields
            )
        ) {
            DocumentSheetReducer()
        }

        await store.send(.readOnlyCustomFields(.delegate(.openDocument(linked)))) {
            $0.destination = .documentDetail(
                DocumentDetailReducer.State(
                    document: Shared(value: linked),
                    isOfflineSnapshot: true,
                    server: $0.server
                )
            )
        }
    }

    @Test
    func dismissingTheSheetClearsTheDestination() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentSheetReducer.State.testValue(section: .customFields)
        ) {
            DocumentSheetReducer()
        }

        await store.send(.readOnlyCustomFields(.delegate(.openDocument(linked)))) {
            $0.destination = .documentDetail(
                DocumentDetailReducer.State(document: Shared(value: linked), server: $0.server)
            )
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    // The sheet is built from the list payload and replaces $document once the full document
    // arrives. The section shares that document rather than copying it at init, or fields the list
    // payload omitted would never appear.
    @Test
    func theSectionSeesFieldsThatArriveWithTheFullDocument() async throws {
        let store = TestStore(
            initialState: DocumentSheetReducer.State.testValue(
                document: .testValue(customFields: [], id: 1),
                section: .customFields
            )
        ) {
            DocumentSheetReducer()
        }
        store.exhaustivity = .off

        #expect(store.state.readOnlyCustomFields.document.customFields.isEmpty)

        let full = Document.testValue(
            customFields: [.init(field: 3, value: .bool(true))],
            id: 1
        )
        await store.send(.documentResult(.success(full)))

        #expect(store.state.readOnlyCustomFields.document.customFields.count == 1)
    }

    @Test
    func theSectionMenuFollowsViewNote() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }

        let state = DocumentSheetReducer.State.testValue(server: server)

        // The sheet is opened from an entrance that was already gated, and then offers its own way
        // back into Notes — so it has to ask the same question again.
        #expect(!state.canViewNotes)
        #expect(!state.visibleSections.contains(.notes))
    }

    // Without change_document every section opens read-only, and Details - which has nothing to
    // show read-only - is not offered at all.
    @Test
    func aUserWhoCannotEditGetsEverySectionButDetailsReadOnly() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewNote, .viewCustomField] }

        let state = DocumentSheetReducer.State.testValue(server: server)

        #expect(!state.isEditable)
        #expect(!state.isCustomFieldsEditable)
        #expect(state.visibleSections == [.content, .customFields, .metadata, .notes])
    }

    // Custom fields answer to their own view_customfield: an editor without it still reads the
    // values the document carries, just not through the editor, whose add menu would be empty.
    @Test
    func anEditorWithoutViewCustomFieldReadsCustomFieldsInstead() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .changeDocument] }

        let state = DocumentSheetReducer.State.testValue(server: server)

        #expect(state.isEditable)
        #expect(!state.isCustomFieldsEditable)
        #expect(state.visibleSections.contains(.customFields))
    }

    // An offline snapshot reads what was saved. Every write the sheet can start is refused even
    // if one is sent, since none of their dependencies are among those the Offline tab overrides:
    // an exhaustive store fails on any effect these would run.
    @Test
    func anOfflineSnapshotRefusesEveryWrite() async throws {
        let store = TestStore(
            initialState: DocumentSheetReducer.State.testValue(
                content: "Some content",
                isOfflineSnapshot: true
            )
        ) {
            DocumentSheetReducer()
        }

        #expect(!store.state.isEditable)
        #expect(!store.state.visibleSections.contains(.details))

        await store.send(.view(.saveButtonTapped))
        await store.send(.view(.getNextArchiveSerialNumberButtonTapped))
        await store.send(.view(.createTagButtonTapped))
        await store.send(.view(.createCorrespondentButtonTapped))
        await store.send(.view(.createDocumentTypeButtonTapped))
        await store.send(.view(.createStoragePathButtonTapped))
        await store.send(.view(.createCustomFieldButtonTapped))
        await store.send(.view(.resetButtonTapped))
    }

    @Test
    func theSectionMenuOpensWithViewNote() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewNote] }

        let state = DocumentSheetReducer.State.testValue(server: server)

        #expect(state.canViewNotes)
        #expect(!state.permissions.can(.addNote))
    }

    @Test
    func theSectionMenuDropsHistoryOnAnotherUsersDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewLogEntry] }
        $auditLogEnabled.withLock { $0 = true }

        let state = DocumentSheetReducer.State.testValue(document: .testValue(owner: 6), server: server)

        #expect(!state.canViewHistory)
    }

    @Test
    func theSectionMenuOffersHistoryOnTheUsersOwnDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewLogEntry] }
        $auditLogEnabled.withLock { $0 = true }

        let state = DocumentSheetReducer.State.testValue(document: .testValue(owner: 5), server: server)

        #expect(state.canViewHistory)
    }
}
