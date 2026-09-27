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

// Every section of a document, in one sheet: what used to be a read-only viewer and a separate
// edit form. Each section is editable when the user may change the document and read-only
// otherwise, so the menus that open it name a section and never a mode.
@Reducer
public struct DocumentSheetReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case documentResult(Result<Document, Error>)
        case history(DocumentHistoryReducer.Action)
        case linkedCustomFieldDocuments(IdentifiedArrayOf<Document>)
        case metadata(DocumentMetadataReducer.Action)
        case nextArchiveSerialNumber(Int)
        case notes(DocumentNotesReducer.Action)
        case readOnlyCustomFields(DocumentCustomFieldsReducer.Action)
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

    // Swift allows the mutual recursion with DocumentDetailReducer, whose own Destination holds
    // this sheet; only the synthesised Equatable needs the hand-written conformance at the bottom
    // of this file, which every Destination in this codebase carries.
    @Reducer
    public enum Destination {
        case correspondentForm(CorrespondentFormReducer)
        case customFieldForm(CustomFieldFormReducer)
        case documentDetail(DocumentDetailReducer)
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

        var history: DocumentHistoryReducer.State

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

        // Carried so a linked document opened from here inherits it: that document is a fresh
        // DocumentDetailReducer, not the one the Offline tab already marked, and would otherwise
        // reach the network same as any other document's.
        let isOfflineSnapshot: Bool

        // An offline document is a snapshot: it reads what was saved, and every write this sheet
        // can otherwise reach - save, the ASN lookup, the create forms, the document picker, the
        // notes composer and delete - must stay unreachable, since none of those dependencies are
        // among the ones the Offline tab overrides for reading.
        var isEditable: Bool {
            canEdit && !isOfflineSnapshot
        }

        // Custom fields answer to their own view_customfield: without it the definitions endpoint
        // is refused, and the editor has nothing to offer in its add menu. The values the document
        // already carries still show, read-only.
        var isCustomFieldsEditable: Bool {
            isEditable && canViewCustomField
        }

        // Only the sections that scroll as one column get the sheet's scroll view. Editable
        // content is a TextEditor that scrolls itself; the lists - notes, history, read-only
        // custom fields - span the sheet edge to edge and scroll themselves too. The loading,
        // error and empty states are centred instead, which a scroll view would pin to the top.
        var isSheetScrollable: Bool {
            switch section {
            case .content:
                guard !isEditable, let content, loadError == nil else {
                    return false
                }
                return !content.isEmpty
            case .customFields:
                return isCustomFieldsEditable && !input.customFields.isEmpty
            case .details:
                return true
            case .history, .notes:
                return false
            case .metadata:
                guard let value = metadata.metadata, metadata.loadError == nil else {
                    return false
                }
                return !value.isEmpty
            }
        }

        var isUpdating = false

        // Resolved titles for every documentlink value on the document, so the capsules can name
        // what they link to. An id with no entry here renders as its id.
        var linkedCustomFieldDocuments: IdentifiedArrayOf<Document> = []

        var loadError: String?

        var metadata: DocumentMetadataReducer.State

        var notes: DocumentNotesReducer.State

        var readOnlyCustomFields: DocumentCustomFieldsReducer.State

        var section = DocumentSheetSection.details

        // The sheet's own picker narrows through the same filter as the menus that open it.
        var visibleSections: [DocumentSheetSection] {
            DocumentSheetSection.visible(
                isEditable: isEditable,
                canViewHistory: canViewHistory,
                canViewNotes: canViewNotes
            )
        }

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

        // Stored rather than computed from `server`: constructing a ServerPermissions reads two
        // files and arms two file watchers, and a computed property would do that on every render.
        var permissions: ServerPermissions

        var canEdit: Bool { permissions.can(.changeDocument) }

        var canViewHistory: Bool { permissions.canViewHistory(of: document) }

        var canCreateTag: Bool { permissions.can(.addTag) }

        var canCreateCorrespondent: Bool { permissions.can(.addCorrespondent) }

        var canCreateDocumentType: Bool { permissions.can(.addDocumentType) }

        var canCreateStoragePath: Bool { permissions.can(.addStoragePath) }

        var canCreateCustomField: Bool { permissions.can(.addCustomField) }

        // A picker is an input, not a rendering of what a document already carries. Without
        // view_<entity> its endpoint answers 403, so it offers an empty list the user cannot fill
        // - a control that looks interactive and does nothing. The document's existing correspondent
        // still shows wherever the payload carries it; this hides only the means of changing it.
        var canViewCorrespondent: Bool { permissions.can(.viewCorrespondent) }

        var canViewCustomField: Bool { permissions.can(.viewCustomField) }

        var canViewDocumentType: Bool { permissions.can(.viewDocumentType) }

        var canViewStoragePath: Bool { permissions.can(.viewStoragePath) }

        var canViewTag: Bool { permissions.can(.viewTag) }

        var canViewNotes: Bool { permissions.can(.viewNote) }

        init(
            destination: DocumentSheetReducer.Destination.State? = nil,
            document: Shared<Document>,
            isOfflineSnapshot: Bool = false,
            section: DocumentSheetSection = .details,
            server: Server
        ) {
            self.destination = destination
            self._document = document
            self.history = DocumentHistoryReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.isOfflineSnapshot = isOfflineSnapshot
            self.section = section
            self.input = DocumentFormInput(
                document: document.wrappedValue,
                server: server
            )
            self.metadata = DocumentMetadataReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.notes = DocumentNotesReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
            self.readOnlyCustomFields = DocumentCustomFieldsReducer.State(
                document: document,
                server: server
            )
            self.server = server
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._customFields = Shared(wrappedValue: [], .customFields(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
            permissions = ServerPermissions(server: server)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.history, action: \.history) {
            DocumentHistoryReducer()
        }
        Scope(state: \.metadata, action: \.metadata) {
            DocumentMetadataReducer()
        }
        Scope(state: \.notes, action: \.notes) {
            DocumentNotesReducer()
        }
        Scope(state: \.readOnlyCustomFields, action: \.readOnlyCustomFields) {
            DocumentCustomFieldsReducer()
        }
        Reduce { state, action in
            switch action {
            case let .readOnlyCustomFields(.delegate(.openDocument(document))):
                state.destination = .documentDetail(DocumentDetailReducer.State(
                    document: Shared(value: document),
                    isOfflineSnapshot: state.isOfflineSnapshot,
                    server: state.server
                ))
                return .none
            // The detail here shows a LINKED document opened from a custom field, not the one this
            // sheet is showing, so deleting it dismisses the detail and leaves the sheet be.
            case let .destination(.presented(.documentDetail(.delegate(.deleteDocument(id))))):
                state.destination = nil
                return .runDeleteDocument(id: id, server: state.server)
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
            // Every write this sheet can start, refused when it is read-only. The view hides each
            // control, so this is the belt to those braces - the one that holds an offline
            // snapshot's promise even if a control is ever left showing.
            case let .view(viewAction) where !state.isEditable && viewAction.isWrite:
                return .none
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
                    // Read-only custom fields resolve their own links; the editor's lookup is for
                    // the staged values, which a read-only sheet never has.
                    let resolveLinked: Effect<Action> = state.isCustomFieldsEditable
                        ? .runResolveLinkedCustomFieldDocuments(state)
                        : .none
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
            case .binding, .delegate, .destination, .history, .metadata, .notes, .readOnlyCustomFields:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

private extension DocumentSheetReducer.Action.View {

    var isWrite: Bool {
        switch self {
        case .addCustomFieldTapped,
             .createCorrespondentButtonTapped,
             .createCustomFieldButtonTapped,
             .createDocumentTypeButtonTapped,
             .createStoragePathButtonTapped,
             .createTagButtonTapped,
             .documentLinkTapped,
             .getNextArchiveSerialNumberButtonTapped,
             .removeCustomFieldTapped,
             .resetButtonTapped,
             .saveButtonTapped:
            true
        case .closeButtonTapped, .onAppear, .retryLoadButtonTapped:
            false
        }
    }
}

extension DocumentSheetReducer.Destination.State: Equatable {}
