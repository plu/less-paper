@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentListDeepLinkTests {

    // The document is on screen already: reuse the row's shared value rather than fetching a second
    // copy, or an edit made through the link never reaches the row behind it.
    @Test
    func openDocument_reusesALoadedDocument() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 42)
        let store = TestStore(
            initialState: DocumentListReducer.State(
                documents: [DocumentRowReducer.State(document: Shared(value: document), server: server)],
                server: server
            ),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { _, _ in
                    Issue.record("a loaded document must not be fetched again")
                    return .testValue()
                }
            }
        )

        await store.send(.openDocument(42)) {
            $0.path.append(.documentDetail(DocumentDetailReducer.State(
                document: Shared(value: document),
                server: server
            )))
        }
    }

    @Test
    func openDocument_fetchesOneTheListDoesNotHave() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 7)
        let store = TestStore(
            initialState: DocumentListReducer.State(server: server),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { id, _ in
                    #expect(id == 7)
                    return document
                }
            }
        )

        // The push lands during an effect, where the stack's element ids do not line up with a
        // second append made in an expectation closure. The outcome is what matters here.
        store.exhaustivity = .off

        await store.send(.openDocument(7))
        await store.receive(\.documentFetched)

        #expect(store.state.path.count == 1)

        if case let .documentDetail(detail) = store.state.path.last {
            #expect(detail.document.id == 7)
            #expect(detail.server == server)
        } else {
            Issue.record("expected the fetched document on the path")
        }
    }

    // Tapping the same link twice is ordinary. Two identical screens stacked on each other is
    // something the user then has to unwind by hand.
    @Test
    func openDocument_popsToADocumentAlreadyOnThePath() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 42)
        let other = Document.testValue(id: 43)
        var path = StackState<DocumentListReducer.Path.State>()
        path.append(.documentDetail(DocumentDetailReducer.State(document: Shared(value: document), server: server)))
        path.append(.documentDetail(DocumentDetailReducer.State(document: Shared(value: other), server: server)))

        let store = TestStore(
            initialState: DocumentListReducer.State(
                documents: [DocumentRowReducer.State(document: Shared(value: document), server: server)],
                path: path,
                server: server
            ),
            reducer: { DocumentListReducer() }
        )

        await store.send(.openDocument(42)) {
            $0.path.removeLast()
        }
    }

    @Test
    func openDocument_reportsAFetchFailure() async {
        let store = TestStore(
            initialState: DocumentListReducer.State(server: .testValue()),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { _, _ in throw TestError.someError }
                // .error both fills the list's inline banner and raises a toast.
                $0.toastPresenter.present = { _ in }
            }
        )
        store.exhaustivity = .off

        await store.send(.openDocument(7))
        await store.receive(\.error)

        #expect(store.state.error == TestError.someError.localizedDescription)
        #expect(store.state.path.isEmpty)
    }
}
