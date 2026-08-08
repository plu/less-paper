import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import DocumentTypesFeature
import Foundation
import PDFKit
import StoragePathsFeature
import SwiftSharing
import TagsFeature

@Reducer
public struct ShareFormReducer {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case fileImported
        case fileUnlocked
        case nextArchiveSerialNumber(Int)
        case view(View)

        public enum Delegate {
            case dismiss
        }

        public enum View {
            case createCorrespondentButtonTapped
            case createDocumentTypeButtonTapped
            case createStoragePathButtonTapped
            case createTagButtonTapped
            case getNextArchiveSerialNumberButtonTapped
            case importButtonTapped
            case skipButtonTapped
            case unlockButtonTapped
        }
    }

    @Reducer
    public enum Destination {
        case correspondentForm(CorrespondentFormReducer)
        case documentTypeForm(DocumentTypeFormReducer)
        case storagePathForm(StoragePathFormReducer)
        case tagForm(TagFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        @Presents
        var destination: Destination.State?

        @Shared
        var correspondents: IdentifiedArrayOf<Correspondent>

        @Shared
        var documentTypes: IdentifiedArrayOf<DocumentType>

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>

        @Shared
        var storagePaths: IdentifiedArrayOf<StoragePath>

        @Shared
        var tags: IdentifiedArrayOf<Tag>

        var currentIndex = 0

        var document: PDFDocument?

        let files: [URL]

        var image: UIImage?

        var input = ShareFormInput()

        var isImporting = false

        var isLoadingNextArchiveSerialNumber = false

        var isLocked: Bool {
            document?.isEncrypted == true && document?.isLocked == true
        }

        var quickLookPreview: URL?

        var server: Server { didSet { reset() } }

        public init(
            files: [URL],
            server: Server
        ) {
            self.files = files
            self.server = server
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            self._tags = Shared(wrappedValue: [], .tags(server))
            selectFile(index: currentIndex)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.correspondentForm(.delegate(.correspondentSaved(correspondent))))):
                state.destination = nil
                state.input.correspondent = correspondent
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
            case let .error(error):
                return .toast(error)
            case .fileImported:
                guard state.hasMoreFiles else {
                    return .send(.delegate(.dismiss))
                }
                state.selectNextFile()
                return .none
            case .fileUnlocked:
                state.document = PDFDocument(url: state.files[state.currentIndex])
                state.image = state.document?.firstPageImage
                return .none
            case let .nextArchiveSerialNumber(archiveSerialNumber):
                state.input.archiveSerialNumber = String(archiveSerialNumber)
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .createCorrespondentButtonTapped:
                    state.destination = .correspondentForm(CorrespondentFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .createDocumentTypeButtonTapped:
                    state.destination = .documentTypeForm(DocumentTypeFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .createStoragePathButtonTapped:
                    state.destination = .storagePathForm(StoragePathFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .createTagButtonTapped:
                    state.destination = .tagForm(TagFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .getNextArchiveSerialNumberButtonTapped:
                    return .runGetNextArchiveSerialNumber(
                        server: state.server
                    )
                case .importButtonTapped:
                    return .runUploadFile(
                        input: state.input,
                        server: state.server,
                        url: state.files[state.currentIndex]
                    )
                case .skipButtonTapped:
                    guard state.hasMoreFiles else {
                        return .send(.delegate(.dismiss))
                    }
                    state.selectNextFile()
                    return .none
                case .unlockButtonTapped:
                    return .runUnlockFile(
                        document: state.document,
                        password: state.input.password,
                        url: state.files[state.currentIndex]
                    )
                }
            case .binding, .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}

extension ShareFormReducer.Destination.State: Equatable {}

extension ShareFormReducer.State {

    var hasMoreFiles: Bool {
        files.indices.contains(currentIndex + 1)
    }

    mutating func reset() {
        input.reset()
        _correspondents = Shared(wrappedValue: [], .correspondents(server))
        _documentTypes = Shared(wrappedValue: [], .documentTypes(server))
        _storagePaths = Shared(wrappedValue: [], .storagePaths(server))
        _tags = Shared(wrappedValue: [], .tags(server))
    }

    mutating func selectNextFile() {
        input = .init()
        selectFile(index: currentIndex + 1)
    }

    mutating func selectFile(index: Int) {
        if files.indices.contains(index) {
            currentIndex = index
            let url = files[index]
            input.title = url.documentTitle
            document = PDFDocument(url: url)
            image = document?.firstPageImage
        }
    }
}
