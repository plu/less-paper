import ApiInterface
import ComposableArchitecture

extension DocumentListReducer.State {

    // One place decides what showing a document detail means, so a deep link and a tapped row
    // cannot disagree about it.
    mutating func presentDocumentDetail(_ document: Shared<Document>) {
        // Already open: pop back to it. Tapping the same link twice is ordinary, and two identical
        // screens stacked on each other is something the user has to unwind by hand.
        for elementId in path.ids {
            guard case let .documentDetail(detail) = path[id: elementId],
                  detail.document.id == document.wrappedValue.id
            else {
                continue
            }

            path.pop(to: elementId)
            return
        }

        // A detail column shows one document: picking a second replaces the first rather than
        // stacking behind it, which is what appending would do and what makes three taps leave
        // three screens deep on iPad.
        if isSplitLayout {
            path.removeAll()
        }

        path.append(.documentDetail(DocumentDetailReducer.State(
            document: document,
            server: server
        )))
    }
}

extension Effect where Action == DocumentListReducer.Action {

    static func runGetDocument(id: Document.Id, server: Server) -> Self {
        @Dependency(\.getDocument.execute)
        var getDocument

        return .run { send in
            await send(.documentFetched(try await getDocument(id, server)))
        } catch: { error, send in
            await send(.error(error))
        }
    }
}
