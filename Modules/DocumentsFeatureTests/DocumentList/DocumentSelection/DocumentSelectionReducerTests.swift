@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Testing

@MainActor
@Suite(
    .dependencies()
)
struct DocumentSelectionReducerTests {

    @Test
    func test_documentTapped_select() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        await store.send(.documentTapped(1)) {
            $0.selectedDocuments = [1]
        }
    }

    @Test
    func test_documentTapped_deselect() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            isActive: true,
            selectedDocuments: [1],
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        await store.send(.documentTapped(1)) {
            $0.selectedDocuments = []
        }
    }

    @Test
    func test_selectAllLoadedButtonTapped() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2, 3],
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        await store.send(.selectAllLoadedButtonTapped) {
            $0.selectedDocuments = [1, 2, 3]
        }
    }

    @Test
    func test_selectAllMatchingButtonTapped() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            allMatchingDocuments: [1, 2, 3, 4, 5],
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        await store.send(.selectAllMatchingButtonTapped) {
            $0.selectedDocuments = [1, 2, 3, 4, 5]
        }
    }

    @Test
    func test_selectAllMatchingButtonTapped_fetchesIdsWhenEmpty() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        } withDependencies: {
            $0.getAllDocumentIds.execute = { _, _ in
                .testValue(results: [
                    DocumentId(id: 1),
                    DocumentId(id: 2),
                    DocumentId(id: 3),
                ])
            }
        }

        await store.send(.selectAllMatchingButtonTapped) {
            $0.isLoading = true
        }
        await store.receive(\.binding, .set(\.allMatchingDocuments, [1, 2, 3])) {
            $0.allMatchingDocuments = [1, 2, 3]
        }
        await store.receive(\.binding, .set(\.selectedDocuments, [1, 2, 3])) {
            $0.selectedDocuments = [1, 2, 3]
        }
        await store.receive(\.binding, .set(\.isLoading, false)) {
            $0.isLoading = false
        }
    }

    @Test
    func test_selectAllMatchingButtonTapped_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        } withDependencies: {
            $0.getAllDocumentIds.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.selectAllMatchingButtonTapped) {
            $0.isLoading = true
        }
        await store.receive(\.binding, .set(\.isLoading, false)) {
            $0.isLoading = false
        }
        await store.receive(\.error)
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_selectNoneButtonTapped() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            allLoadedDocuments: [1, 2],
            isActive: true,
            selectedDocuments: [1, 2],
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        await store.send(.selectNoneButtonTapped) {
            $0.selectedDocuments = []
        }
    }

    @Test
    func test_toggleSelectionModeButtonTapped_activate() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }
        let filter = DocumentFilter.testValue(input: .testValue(searchValue: "Invoice"))

        await store.send(.toggleSelectionModeButtonTapped(filter)) {
            $0.filter = filter
            $0.isActive = true
        }
    }

    @Test
    func test_toggleSelectionModeButtonTapped_deactivate() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            isActive: true,
            selectedDocuments: [1, 2],
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }
        let filter = DocumentFilter.testValue(input: .testValue(searchValue: "Invoice"))

        await store.send(.toggleSelectionModeButtonTapped(filter)) {
            $0.filter = filter
            $0.isActive = false
            $0.selectedDocuments = []
        }
    }

    @Test
    func test_tabBarVisibility_hidden() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            isActive: true,
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        #expect(store.state.tabBarVisibility == .hidden)
    }

    @Test
    func test_tabBarVisibility_automatic() async throws {
        let store = TestStore(initialState: DocumentSelectionReducer.State(
            server: .testValue()
        )) {
            DocumentSelectionReducer()
        }

        #expect(store.state.tabBarVisibility == .automatic)
    }
}
