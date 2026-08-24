@testable import DocumentsFeature

import ApiInterface
import Clocks
import Components
import ComposableArchitecture
import CustomDump
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct CustomFieldQueryDocumentPickerReducerTests {

    // A burst of keystrokes must produce one request, not one per character.
    @Test
    func searchIsDebounced() async {
        let clock = TestClock()
        let store = TestStore(initialState: .testValue()) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable _, _ in .testValue(count: 1, results: [puky]) }
        }

        await store.send(.binding(.set(\.searchText, "pu"))) { $0.searchText = "pu" }
        await store.send(.binding(.set(\.searchText, "puk"))) { $0.searchText = "puk" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.documentsLoaded) {
            $0.documents = [puky]
            $0.isLoading = false
        }
    }

    @Test
    func theSearchSendsTitleIcontainsNewestFirst() async {
        let clock = TestClock()
        let inputs = LockIsolated([GetDocumentsInput]())
        let store = TestStore(initialState: .testValue()) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable input, _ in
                inputs.withValue { $0.append(input) }
                return .testValue()
            }
        }

        await store.send(.binding(.set(\.searchText, "puky"))) { $0.searchText = "puky" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.documentsLoaded) { $0.isLoading = false }

        expectNoDifference(inputs.value.map(\.filterRules), [[.init(ruleType: .title, value: "puky")]])
        expectNoDifference(inputs.value.map(\.sortField), [.created])
        expectNoDifference(inputs.value.map(\.sortDirection), [.descending])
    }

    // An empty query lists the most recent documents rather than nothing, as the web does.
    @Test
    func anEmptyQuerySendsNoFilterRule() async {
        let clock = TestClock()
        let inputs = LockIsolated([GetDocumentsInput]())
        let store = TestStore(initialState: .testValue(searchText: "x")) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable input, _ in
                inputs.withValue { $0.append(input) }
                return .testValue()
            }
        }

        await store.send(.binding(.set(\.searchText, ""))) { $0.searchText = "" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.documentsLoaded) { $0.isLoading = false }

        expectNoDifference(inputs.value.map(\.filterRules), [[]])
    }

    @Test
    func tappingADocumentSelectsAndDeselectsIt() async {
        let store = TestStore(initialState: .testValue(documents: [puky])) {
            CustomFieldQueryDocumentPickerReducer()
        }

        await store.send(.view(.documentTapped(10))) { $0.selection = [puky] }
        await store.receive(\.delegate.selectionChanged, [10])

        await store.send(.view(.documentTapped(10))) { $0.selection = [] }
        await store.receive(\.delegate.selectionChanged, [])
    }

    // The whole reason `selection` holds documents rather than ids: without this the selection
    // disappears from the list as soon as the query stops matching it, and cannot be removed.
    @Test
    func aSelectedDocumentStaysListedWhenTheQueryNoLongerMatchesIt() {
        let state = CustomFieldQueryDocumentPickerReducer.State.testValue(
            documents: [invoice],
            selection: [puky]
        )

        expectNoDifference(state.rows.map(\.id), [10, 11])
    }

    @Test
    func aSelectedDocumentIsNotListedTwice() {
        let state = CustomFieldQueryDocumentPickerReducer.State.testValue(
            documents: [puky, invoice],
            selection: [puky]
        )

        expectNoDifference(state.rows.map(\.id), [10, 11])
    }

    @Test
    func selectionIsEmittedSorted() async {
        let store = TestStore(initialState: .testValue(documents: [invoice], selection: [puky])) {
            CustomFieldQueryDocumentPickerReducer()
        }

        await store.send(.view(.documentTapped(11))) { $0.selection = [puky, invoice] }
        await store.receive(\.delegate.selectionChanged, [10, 11])
    }

    // A failed search must not throw away what the user already picked.
    @Test
    func aFailedSearchToastsAndKeepsTheSelection() async {
        let clock = TestClock()
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(selection: [puky])) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.binding(.set(\.searchText, "x"))) { $0.searchText = "x" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.error) { $0.isLoading = false }

        #expect(toasts.value == [.error("Something went wrong")])
        expectNoDifference(store.state.selection, [puky])
    }
}

// File scope rather than statics on the suite: the suite is `@MainActor`, and a `@Sendable`
// dependency closure cannot reach main-actor-isolated state.
private let invoice = Document.testValue(id: 11, title: "Invoice")

private let puky = Document.testValue(id: 10, title: "Puky-Locked")
