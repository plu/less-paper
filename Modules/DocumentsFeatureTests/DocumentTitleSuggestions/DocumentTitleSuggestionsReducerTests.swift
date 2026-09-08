@testable import DocumentsFeature

import ComposableArchitecture
import Intelligence
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentTitleSuggestionsReducerTests {

    @Test
    func test_view_onAppear_streamsSuggestions() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["First"])
                    continuation.yield(["First", "Second"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        // Each snapshot carries the whole list, so state is replaced rather than appended to.
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["First"]
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["First", "Second"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }

    @Test
    func test_view_suggestionTapped_delegatesTheTitle() async throws {
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(suggestions: ["Chosen"])
        ) {
            DocumentTitleSuggestionsReducer()
        }

        await store.send(.view(.suggestionTapped("Chosen")))
        await store.receive(\.delegate.titleSelected)
    }

    @Test
    func test_view_regenerateButtonTapped_clearsTheOldRowsFirst() async throws {
        // Rows are keyed by index, so a new stream filling into a populated array would show a mix
        // of old and new titles while it ran.
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(suggestions: ["Old"])
        ) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["New"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.regenerateButtonTapped)) {
            $0.isGenerating = true
            $0.suggestions = []
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["New"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_guardrailViolation_saysTheModelDeclined() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.guardrailViolation) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionDeclined)
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_contextWindowExceeded_saysTheDocumentIsTooLong() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.contextWindowExceeded) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionTooLong)
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_otherError_fallsBackToTheGenericMessage() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.failed("boom")) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionFailed)
            $0.isGenerating = false
        }
    }

    @Test
    func test_view_retryButtonTapped_clearsTheError() async throws {
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(
                error: String(localized: .titleSuggestionFailed)
            )
        ) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["Recovered"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.retryButtonTapped)) {
            $0.error = nil
            $0.isGenerating = true
            $0.suggestions = []
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["Recovered"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }
}
