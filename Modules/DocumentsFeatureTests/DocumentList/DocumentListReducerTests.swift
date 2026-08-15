@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentListReducerTests {

    @Test
    func test_documents_delegate_presentDocumentDetail() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [.testValue()]
        )) {
            DocumentListReducer()
        }

        await store.send(.documents(.element(id: 1, action: .delegate(.presentDocumentDetail(Shared(value: .testValue())))))) {
            $0.path.append(.documentDetail(.testValue()))
        }
    }

    @Test
    func test_destination_documentFilter_delegate_filterUpdated() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .documentFilter(.testValue(input: .testValue(searchValue: "Lego"))),
            filter: .testValue(input: .testValue(searchValue: "Lego"))
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.destination(.presented(.documentFilter(.delegate(.filterUpdated(.testValue(
            input: .testValue(searchValue: "Invoice"),
            savedView: .testValue(name: "All Invoices")
        ))))))) {
            $0.filter.input = .testValue(searchValue: "Invoice")
            $0.filter.savedView = .testValue(name: "All Invoices")
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    @Test
    func test_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [.testValue()]
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.error(ApiError.testValue())) {
            $0.error = "Something went wrong"
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_navigationTitle_allDocuments() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }

        #expect(store.state.navigationTitle == .allDocuments)
    }

    @Test
    func test_navigationTitle_savedView() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(savedView: .testValue())
        )) {
            DocumentListReducer()
        }

        #expect(store.state.navigationTitle == "Test SavedView")
    }

    @Test
    /// The list no longer propagates the edit itself — the shared store does, so all this
    /// action still has to do is dismiss the form nested in the detail screen.
    func test_path_documentDetail_destination_documentForm_delegate_documentUpdated() async throws {
        let document = Document.testValue(id: 1, title: "Original Title")

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: document)
            ],
            path: .init([
                .documentDetail(.testValue(
                    destination: .documentForm(.testValue()),
                    document: document
                ))
            ])
        )) {
            DocumentListReducer()
        }

        await store.send(.path(.element(
            id: 0,
            action: .documentDetail(.destination(.presented(.documentForm(.delegate(.documentUpdated)))))
        ))) {
            $0.path[id: 0, case: \.documentDetail]?.destination = nil
        }
    }

    @Test
    func test_view_allDocumentsButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(searchValue: "Lego"),
                savedView: .testValue()
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.view(.allDocumentsButtonTapped)) {
            $0.filter = .init()
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    @Test
    func test_view_filterButtonTapped() async throws {
        let filter = DocumentFilter.testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        )
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: filter
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.filterButtonTapped)) {
            $0.destination = .documentFilter(.testValue(
                input: filter.input,
                savedView: filter.savedView
            ))
        }
    }

    @Test
    func test_view_importButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }

        await store.send(.view(.importButtonTapped))
        await store.receive(\.documentImport) {
            $0.documentImport.isPresentingFileImporter = true
        }
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: []
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.error) {
            $0.error = "Something went wrong"
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_onAppear_withDocuments() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [.testValue()]
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_withoutDocuments() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: []
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    /// The Inbox filter is built in `MainReducer.State.init`, before this session's caches land.
    /// Fetching re-derives it, so a first launch does not keep filtering by an empty tag set.
    @Test
    func test_view_onAppear_inbox_rebuildsFilterFromCaches() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = [104]

        @Shared(.tags(server))
        var tags: IdentifiedArrayOf<ApiInterface.Tag> = [
            .testValue(id: 104, isInboxTag: true, name: "Inbox")
        ]

        let filterRulesUsed = LockIsolated<[FilterRule]?>(nil)

        // Built while the caches were still empty, as it is on a cold start.
        var staleInboxFilter = DocumentFilter()
        staleInboxFilter.isInbox = true

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [],
            filter: staleInboxFilter,
            server: server
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { input, _ in
                filterRulesUsed.setValue(input.filterRules)
                return .testValue(count: 1, results: [.testValue()])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.filter = .inbox(server: server)
        }
        await store.receive(\.replaceDocuments) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 1
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        #expect(filterRulesUsed.value == [.init(ruleType: .hasTagsAny, value: "104")])
    }

    /// An empty tag selection produces no tag rule, so fetching would ask for every document.
    /// An inbox with no inbox tags is simply empty.
    @Test
    func test_view_onAppear_inbox_withoutInboxTags_doesNotFetchEverything() async throws {
        let server = Server.testValue()

        @Shared(.inboxTags(server))
        var inboxTags: [ApiInterface.Tag.Id] = []

        var inboxFilter = DocumentFilter()
        inboxFilter.isInbox = true

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [],
            filter: inboxFilter,
            server: server,
            totalNumberOfDocuments: 42
        )) {
            DocumentListReducer()
        }

        // `getDocuments` is left unimplemented: reaching it would fail the test.
        await store.send(.view(.onAppear)) {
            $0.filter = .inbox(server: server)
            $0.isLoaded = true
            $0.totalNumberOfDocuments = 0
        }
    }

    @Test
    func test_view_refresh() async throws {
        let statisticsServers = LockIsolated<[Server]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
                .testValue(document: .testValue(id: 2)),
                .testValue(document: .testValue(id: 3)),
            ]
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
            $0.getStatistics.execute = { server in
                statisticsServers.withValue { $0.append(server) }
                return .testValue()
            }
        }

        await store.send(.view(.onRefresh))
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        // A pull-to-refresh is an explicit "show me the current state" gesture, so it also
        // re-reads the counts behind the Inbox badge.
        await store.finish()
        #expect(statisticsServers.value == [.testValue()])
    }

    @Test
    func test_view_onRowAppear_withoutNextPage() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
                .testValue(document: .testValue(id: 2)),
                .testValue(document: .testValue(id: 3)),
            ],
            nextPage: nil
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.onRowAppear(.testValue(id: 3))))
    }

    @Test
    func test_view_onRowAppear_withNextPage() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
                .testValue(document: .testValue(id: 2)),
                .testValue(document: .testValue(id: 3)),
            ],
            documentSelection: .testValue(
                allLoadedDocuments: [1, 2, 3]
            ),
            nextPage: .testValue()
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 4,
                    next: nil,
                    results: [.testValue(id: 4)]
                )
            }
        }

        await store.send(.view(.onRowAppear(.testValue(id: 1))))
        await store.send(.view(.onRowAppear(.testValue(id: 2))))
        await store.send(.view(.onRowAppear(.testValue(id: 3)))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.appendDocuments, .testValue(
            count: 4,
            results: [.testValue(id: 4)]
        )) {
            $0.documents.append(.testValue(document: .testValue(id: 4)))
            $0.$documentCache.withLock { $0 = [.testValue(id: 4)] }
            $0.documentSelection.allLoadedDocuments = [1, 2, 3, 4]
            $0.nextPage = nil
            $0.totalNumberOfDocuments = 4
        }
        await store.receive(\.binding, .set(\.isLoadingMore, false)) {
            $0.isLoadingMore = false
        }
    }

    @Test
    func test_view_onRowAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
            ],
            nextPage: .testValue()
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onRowAppear(.testValue(id: 1)))) {
            $0.isLoadingMore = true
        }
        await store.receive(\.error) {
            $0.error = "Something went wrong"
        }
        await store.receive(\.binding, .set(\.isLoadingMore, false)) {
            $0.isLoadingMore = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_savedViewButtonTapped() async throws {
        let savedView = SavedView.testValue(
            filterRules: [.init(ruleType: .titleContent, value: "Lego")]
        )
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(searchValue: "Invoice"),
                savedView: nil
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.view(.savedViewButtonTapped(savedView))) {
            $0.filter.input = .testValue(searchValue: "Lego")
            $0.filter.savedView = savedView
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    @Test
    func test_view_scanButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }

        await store.send(.view(.scanButtonTapped))
        await store.receive(\.documentImport) {
            $0.documentImport.isPresentingDocumentScanner = true
        }
    }

    @Test
    func test_view_toggleSelectionModeButtonTapped_activate() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
                .testValue(document: .testValue(id: 2)),
            ]
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.toggleSelectionModeButtonTapped))
        await store.receive(\.documentSelection) {
            $0.documentSelection.isActive = true
        }
    }

    @Test
    func test_view_toggleSelectionModeButtonTapped_deactivate() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: .testValue(id: 1)),
                .testValue(document: .testValue(id: 2)),
            ],
            documentSelection: DocumentSelectionReducer.State(
                isActive: true,
                selectedDocuments: [1, 2],
                server: .testValue()
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.toggleSelectionModeButtonTapped))
        await store.receive(\.documentSelection) {
            $0.documentSelection.isActive = false
            $0.documentSelection.selectedDocuments = []
        }
    }

    @Test
    func test_view_editCorrespondentButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editCorrespondentButtonTapped)) {
            $0.destination = .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.correspondents
            ))
        }
    }

    @Test
    func test_view_editDocumentTypeButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editDocumentTypeButtonTapped)) {
            $0.destination = .bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.documentTypes
            ))
        }
    }

    @Test
    func test_view_editStoragePathButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editStoragePathButtonTapped)) {
            $0.destination = .bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.storagePaths
            ))
        }
    }

    @Test
    func test_destination_bulkEditCorrespondent_documentsUpdated() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>.State(
                documents: [1, 2],
                server: .testValue(),
                values: []
            )),
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated([1, 2])))))) {
            $0.destination = nil
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
            $0.$documentCache.withLock { $0 = [.testValue()] }
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        #expect(store.state.documentSelection.isActive == true)
        #expect(store.state.documentSelection.selectedDocuments == [1, 2])
    }

    @Test
    func test_view_editTagsButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editTagsButtonTapped)) {
            $0.destination = .bulkEditTags(DocumentBulkEditTagsReducer.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.tags
            ))
        }
    }

    /// Document 7 is in the shared store but is not returned by this list's own re-fetch —
    /// exactly the case the self-re-fetch alone would leave stale in the other tab.
    @Test
    func test_destination_bulkEditTags_documentsUpdated_refreshesAffectedDocuments() async throws {
        let refetched = Document.testValue(id: 1, title: "Refetched")
        let refreshed = Document.testValue(id: 7, title: "Refreshed")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .bulkEditTags(DocumentBulkEditTagsReducer.State(
                documents: [1, 7],
                server: .testValue(),
                values: []
            )),
            documents: [],
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 7]
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [refetched]
                )
            }
            $0.getDocumentsByIds.execute = { input, _ in
                #expect(input.ids == [7])
                return [refreshed]
            }
        }
        store.exhaustivity = .off

        // Load document 7 into the store. The bulk edit's own re-fetch below returns only
        // document 1, so 7 is exactly the case the self-re-fetch cannot keep fresh.
        await store.send(.replaceDocuments(.testValue(
            count: 1,
            results: [.testValue(id: 7, title: "Invoice")]
        )))
        #expect(Array(store.state.documentCache.ids) == [7])

        await store.send(.destination(.presented(.bulkEditTags(.delegate(.documentsUpdated([1, 7])))))) {
            $0.destination = nil
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [refetched]
        )) {
            $0.documents = [.testValue(document: refetched)]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
        }
        await store.receive(\.documentsRefreshed, [refreshed])
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        // Document 7 was refreshed even though it dropped out of this list.
        #expect(store.state.documentCache[id: 7] == refreshed)
        #expect(store.state.documentCache[id: 1] == refetched)
        #expect(store.state.documentSelection.selectedDocuments == [1, 7])
    }

    @Test
    func test_replaceDocuments_cachesDocuments() async throws {
        let document = Document.testValue(id: 7, title: "Invoice")
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: []
        )) {
            DocumentListReducer()
        }

        await store.send(.replaceDocuments(.testValue(
            count: 1,
            results: [document]
        ))) {
            $0.documents = [.testValue(document: document)]
            $0.documentSelection.allLoadedDocuments = [7]
            $0.totalNumberOfDocuments = 1
            $0.$documentCache.withLock { $0 = [document] }
        }
    }

    @Test
    func test_documentDetail_referencesDocumentCache() async throws {
        let state = DocumentListReducer.State.testValue(documents: [])
        let rows = state.rows(for: [.testValue(id: 7, title: "Invoice")])
        let detail = DocumentDetailReducer.State(
            document: rows[id: 7]!.$document,
            server: state.server
        )

        state.$documentCache.withLock {
            $0[id: 7] = .testValue(id: 7, title: "Renamed")
        }

        #expect(detail.document.title == "Renamed")
    }

    @Test
    func test_rows_referenceDocumentCache() async throws {
        let state = DocumentListReducer.State.testValue(documents: [])
        let rows = state.rows(for: [.testValue(id: 7, title: "Invoice")])

        state.$documentCache.withLock {
            $0[id: 7] = .testValue(id: 7, title: "Renamed")
        }

        #expect(rows[id: 7]?.document.title == "Renamed")
    }

    @Test
    func test_documents_element_delegate_deleteDocument_success() async throws {
        let idsReceived = LockIsolated<[Document.Id]?>(nil)
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                allLoadedDocuments: [1, 2, 3, 4],
                allMatchingDocuments: [1, 2, 3, 4],
                selectedDocuments: [1, 2]
            ),
            path: StackState([.documentDetail(.testValue(document: .testValue(id: 2)))])
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { ids, _ in
                idsReceived.setValue(ids)
            }
        }

        await store.send(.documents(.element(id: 2, action: .delegate(.deleteDocument))))
        await store.receive(\.isUpdating) {
            $0.documents[id: 2]?.isUpdating = true
        }
        await store.receive(\.documentsDeleted, [2]) {
            $0.documents.remove(id: 2)
            $0.documentSelection.allLoadedDocuments = [1, 3, 4]
            $0.documentSelection.allMatchingDocuments = [1, 3, 4]
            $0.documentSelection.selectedDocuments = [1]
            $0.path = StackState()
            $0.totalNumberOfDocuments = 41
        }
        await store.receive(\.delegate, .documentsDeleted([2]))

        #expect(idsReceived.value == [2])
    }

    @Test
    func test_documents_element_delegate_deleteDocument_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        } withDependencies: {
            $0.deleteDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.documents(.element(id: 2, action: .delegate(.deleteDocument))))
        await store.receive(\.isUpdating) {
            $0.documents[id: 2]?.isUpdating = true
        }
        await store.receive(\.deleteDocumentsFailed) {
            $0.documents[id: 2]?.isUpdating = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
        #expect(store.state.documents.ids.elements == [1, 2, 3, 4])
        #expect(store.state.error == nil)
    }

    @Test
    func test_documentsDeleted_leavesUnrelatedStateAlone() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(selectedDocuments: [1, 3]),
            path: StackState([.documentDetail(.testValue(document: .testValue(id: 3)))])
        )) {
            DocumentListReducer()
        }

        await store.send(.documentsDeleted([99]))

        #expect(store.state.documents.ids.elements == [1, 2, 3, 4])
        #expect(store.state.documentSelection.selectedDocuments == [1, 3])
        #expect(store.state.path.count == 1)
        #expect(store.state.totalNumberOfDocuments == 42)
    }
}
