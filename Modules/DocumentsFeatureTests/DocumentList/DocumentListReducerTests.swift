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

        await store.send(.documents(.element(id: 1, action: .delegate(.presentDocumentDetail(.testValue()))))) {
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
    func test_path_documentDetail_destination_documentForm_delegate_documentUpdated() async throws {
        let originalDocument = Document.testValue(id: 1, title: "Original Title")
        let updatedDocument = Document.testValue(id: 1, title: "Updated Title")

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documents: [
                .testValue(document: originalDocument)
            ],
            path: .init([
                .documentDetail(.testValue(
                    destination: .documentForm(.testValue()),
                    document: originalDocument
                ))
            ])
        )) {
            DocumentListReducer()
        }

        await store.send(.path(.element(
            id: 0,
            action: .documentDetail(.destination(.presented(.documentForm(.delegate(.documentUpdated(updatedDocument))))))
        ))) {
            $0.documents[id: updatedDocument.id]?.document = updatedDocument
            $0.path[id: 0, case: \.documentDetail]?.destination = nil
            $0.path[id: 0, case: \.documentDetail]?.document = updatedDocument
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
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    @Test
    func test_view_refresh() async throws {
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
        }

        await store.send(.view(.onRefresh))
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
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

        await store.send(.destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated))))) {
            $0.destination = nil
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        #expect(store.state.documentSelection.isActive == true)
        #expect(store.state.documentSelection.selectedDocuments == [1, 2])
    }
}
