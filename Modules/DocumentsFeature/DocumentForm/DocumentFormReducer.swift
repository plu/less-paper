import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import CustomFieldsFeature
import DocumentTypesFeature
import Foundation
import StoragePathsFeature
import Tagged
import TagsFeature

@Reducer
public struct DocumentFormReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case documentResult(Result<Document, Error>)
        case linkedCustomFieldDocuments(IdentifiedArrayOf<Document>)
        case nextArchiveSerialNumber(Int)
        case notes(DocumentNotesReducer.Action)
        case updateResult(Result<Document, Error>)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentUpdated
        }

        public enum View {
            case addCustomFieldTapped(CustomField.Id)
            case createCorrespondentButtonTapped
            case createCustomFieldButtonTapped
            case createDocumentTypeButtonTapped
            case createStoragePathButtonTapped
            case createTagButtonTapped
            case closeButtonTapped
            case documentLinkTapped(CustomField.Id)
            case getNextArchiveSerialNumberButtonTapped
            case onAppear
            case removeCustomFieldTapped(CustomField.Id)
            case resetButtonTapped
            case retryLoadButtonTapped
            case saveButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case correspondentForm(CorrespondentFormReducer)
        case customFieldForm(CustomFieldFormReducer)
        case documentPicker(DocumentPickerReducer)
        case documentTypeForm(DocumentTypeFormReducer)
        case storagePathForm(StoragePathFormReducer)
        case tagForm(TagFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        // nil until the full document arrives. The list truncates content, so nil is the only
        // honest value beforehand — and it is what keeps a partial save impossible.
        var content: String?

        @Presents
        var destination: Destination.State?

        var documentLinkFieldId: CustomField.Id?

        @Shared
        var document: Document

        var input: DocumentFormInput

        var isContentModified: Bool {
            guard let content else {
                return false
            }
            return content != document.content
        }

        var isLoadingDocument = false

        var isLoadingNextArchiveSerialNumber = false

        var isModified: Bool {
            input != DocumentFormInput(document: document, server: server) || isContentModified
        }

        var isUpdating = false

        // Resolved titles for every documentlink value on the document, so the capsules can name
        // what they link to. An id with no entry here renders as its id.
        var linkedCustomFieldDocuments: IdentifiedArrayOf<Document> = []

        var loadError: String?

        var notes: DocumentNotesReducer.State

        var section = DocumentFormSection.details

        let server: Server

        @Shared
        var correspondents: IdentifiedArrayOf<Correspondent>

        @Shared
        var customFields: IdentifiedArrayOf<CustomField>

        @Shared
        var documentTypes: IdentifiedArrayOf<DocumentType>

        @Shared
        var storagePaths: IdentifiedArrayOf<StoragePath>

        @Shared
        var tags: IdentifiedArrayOf<Tag>

        init(
            destination: DocumentFormReducer.Destination.State? = nil,
            document: Shared<Document>,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.input = DocumentFormInput(
                document: document.wrappedValue,
                server: server
            )
            self.notes = DocumentNotesReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.server = server
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._customFields = Shared(wrappedValue: [], .customFields(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.notes, action: \.notes) {
            DocumentNotesReducer()
        }
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.correspondentForm(.delegate(.correspondentSaved(correspondent))))):
                state.destination = nil
                state.input.correspondent = correspondent
                return .none
            case let .destination(.presented(.customFieldForm(.delegate(.customFieldSaved(field))))):
                state.destination = nil
                // Attached straight away: the user opened this form from the add menu, so creating
                // the definition and putting it on the document is one intent.
                guard state.input.customFields[id: field.id] == nil else {
                    return .none
                }
                state.input.customFields.append(
                    DocumentFormCustomField(id: field.id, value: .empty(field: field))
                )
                return .none
            case let .destination(.presented(.documentPicker(.delegate(.selectionChanged(ids))))):
                guard let fieldId = state.documentLinkFieldId else {
                    return .none
                }
                state.input.customFields[id: fieldId]?.value = .documentLink(ids)
                for document in state.destination?.documentPicker?.selection ?? []
                    where state.linkedCustomFieldDocuments[id: document.id] == nil {
                    state.linkedCustomFieldDocuments.append(document)
                }
                return .none
            case .destination(.dismiss):
                state.documentLinkFieldId = nil
                return .none
            case let .destination(.presented(.documentTypeForm(.delegate(.documentTypeSaved(documentType))))):
                state.destination = nil
                state.input.documentType = documentType
                return .none
            case let .destination(.presented(.storagePathForm(.delegate(.storagePathSaved(storagePath))))):
                state.destination = nil
                state.input.storagePath = storagePath
                return .none
            case let .destination(.presented(.tagForm(.delegate(.tagSaved(tag))))):
                state.destination = nil
                state.input.tags.insert(tag)
                return .none
            case let .documentResult(result):
                state.isLoadingDocument = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(document):
                    state.loadError = nil
                    // Only content is re-seeded. The user may have edited the other fields while
                    // this was in flight, and the truncated payload differs from the full one in
                    // content alone.
                    state.content = document.content
                    state.$document.withLock { $0 = document }
                    return .none
                }
            case let .linkedCustomFieldDocuments(documents):
                state.linkedCustomFieldDocuments = documents
                return .none
            case let .nextArchiveSerialNumber(archiveSerialNumber):
                state.input.archiveSerialNumber = String(archiveSerialNumber)
                return .none
            case let .updateResult(result):
                switch result {
                case let .failure(error):
                    return .toast(error)
                case let .success(document):
                    state.$document.withLock { $0 = document }
                    return .send(.delegate(.documentUpdated))
                }
            case let .view(viewAction):
                switch viewAction {
                case let .addCustomFieldTapped(id):
                    // Resolved through the cache rather than `state.customFields`, matching how
                    // `DocumentFormInput` reads definitions. The shared array is the view's menu;
                    // the reducer only ever needs the one field being attached.
                    guard state.input.customFields[id: id] == nil,
                          let field = id.get(state.server)
                    else {
                        return .none
                    }
                    state.input.customFields.append(
                        DocumentFormCustomField(id: id, value: .empty(field: field))
                    )
                    return .none
                case .createCorrespondentButtonTapped:
                    state.destination = .correspondentForm(CorrespondentFormReducer.State(server: state.server))
                    return .none
                case .createCustomFieldButtonTapped:
                    state.destination = .customFieldForm(CustomFieldFormReducer.State(server: state.server))
                    return .none
                case .createDocumentTypeButtonTapped:
                    state.destination = .documentTypeForm(DocumentTypeFormReducer.State(server: state.server))
                    return .none
                case .createStoragePathButtonTapped:
                    state.destination = .storagePathForm(StoragePathFormReducer.State(server: state.server))
                    return .none
                case .createTagButtonTapped:
                    state.destination = .tagForm(TagFormReducer.State(server: state.server))
                    return .none
                case .closeButtonTapped:
                    state.destination = nil
                    return .runDismiss()
                case let .documentLinkTapped(id):
                    guard case let .documentLink(ids) = state.input.customFields[id: id]?.value else {
                        return .none
                    }
                    state.documentLinkFieldId = id
                    state.destination = .documentPicker(DocumentPickerReducer.State(
                        selection: IdentifiedArray(
                            uniqueElements: ids.compactMap { state.linkedCustomFieldDocuments[id: $0] }
                        ),
                        server: state.server
                    ))
                    return .none
                case .getNextArchiveSerialNumberButtonTapped:
                    return .runGetNextArchiveSerialNumber(server: state.server)
                case .onAppear:
                    let resolveLinked = Effect.runResolveLinkedCustomFieldDocuments(state)
                    // A failed load is not retried silently on the next appearance; that is what
                    // the retry button is for. The title lookup still runs: it is keyed off the
                    // staged values, not off whether the full document has arrived.
                    guard state.content == nil, state.loadError == nil, !state.isLoadingDocument else {
                        return resolveLinked
                    }
                    state.isLoadingDocument = true
                    return .merge(
                        resolveLinked,
                        .runGetDocument(
                            id: state.document.id,
                            server: state.server
                        )
                    )
                case let .removeCustomFieldTapped(id):
                    state.input.customFields.remove(id: id)
                    return .none
                case .retryLoadButtonTapped:
                    guard !state.isLoadingDocument else {
                        return .none
                    }
                    state.isLoadingDocument = true
                    state.loadError = nil
                    return .runGetDocument(
                        id: state.document.id,
                        server: state.server
                    )
                case .resetButtonTapped:
                    state.input = DocumentFormInput(
                        document: state.document,
                        server: state.server
                    )
                    // Guarded: an unloaded reset must leave nil in place rather than adopt the
                    // truncated string from the list.
                    if state.content != nil {
                        state.content = state.document.content
                    }
                    return .none
                case .saveButtonTapped:
                    return .runUpdateDocument(
                        content: state.isContentModified ? state.content : nil,
                        id: state.document.id,
                        input: state.input,
                        server: state.server
                    )
                }
            case .binding, .delegate, .destination, .notes:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DocumentFormReducer.Destination.State: Equatable {}
