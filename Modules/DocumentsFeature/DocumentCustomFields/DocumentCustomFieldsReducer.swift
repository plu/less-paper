import ApiInterface
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentCustomFieldsReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case linkedDocuments(IdentifiedArrayOf<Document>)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            case openDocument(Document)
        }

        public enum View {
            case documentLinkTapped(Document.Id)
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        @Shared
        var customFields: IdentifiedArrayOf<CustomField>

        @Shared
        var document: Document

        var linkedDocuments: IdentifiedArrayOf<Document> = []

        let server: Server

        // A field whose definition has been deleted keeps its id as a name: the document still
        // carries the value, and dropping the row would under-report what is on the document.
        var rows: [DocumentCustomFieldRow] {
            document.customFields.map { attached in
                let definition = customFields[id: attached.field]
                return DocumentCustomFieldRow(
                    definition: definition,
                    id: attached.field,
                    name: definition?.name ?? "#\(attached.field.rawValue)",
                    value: definition.map {
                        DocumentFormCustomFieldValue(field: $0, json: attached.value)
                    }
                )
            }
        }

        init(
            document: Shared<Document>,
            server: Server
        ) {
            self._customFields = Shared(wrappedValue: [], .customFields(server))
            self._document = document
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .linkedDocuments(documents):
                state.linkedDocuments = documents
                return .none
            case .delegate:
                return .none
            case let .view(viewAction):
                switch viewAction {
                case let .documentLinkTapped(id):
                    guard let document = state.linkedDocuments[id: id] else {
                        return .none
                    }
                    return .send(.delegate(.openDocument(document)))
                case .onAppear:
                    return .runResolveLinkedDocuments(state)
                }
            }
        }
    }
}

struct DocumentCustomFieldRow: Equatable, Identifiable {

    let definition: CustomField?

    let id: CustomField.Id

    let name: String

    let value: DocumentFormCustomFieldValue?
}
