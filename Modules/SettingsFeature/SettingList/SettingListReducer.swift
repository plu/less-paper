import ApiInterface
import Components
import ComposableArchitecture
import CorrespondentsFeature
import CustomFieldsFeature
import Dependencies
import DiagnosticsFeature
import DocumentTypesFeature
import Foundation
import LicensesFeature
import PdfPasswordsFeature
import SavedViewsFeature
import ServersFeature
import ShareFeature
import StoragePathsFeature
import TagsFeature
import TipsFeature
import TrashFeature

@Reducer
public struct SettingListReducer {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case documentImport(DocumentImportReducer.Action)
        case path(StackActionOf<Path>)
        case view(View)

        public enum View {
            case importButtonTapped
            case scanButtonTapped
        }
    }

    @Reducer
    public enum Destination {}

    @Reducer
    public enum Path {
        case correspondentList(CorrespondentListReducer)
        case customFieldList(CustomFieldListReducer)
        case diagnosticsList(DiagnosticsListReducer)
        case documentTypeList(DocumentTypeListReducer)
        case favoriteSettings(FavoriteSettingsReducer)
        case licenseList(LicenseListReducer)
        case pdfPasswordList(PdfPasswordListReducer)
        case savedViewList(SavedViewListReducer)
        case serverList(ServerListReducer)
        case storagePathList(StoragePathListReducer)
        case tagList(TagListReducer)
        case tipList(TipListReducer)
        case trashList(TrashListReducer)

        @ReducerCaseIgnored
        case license(License)
    }

    @ObservableState
    public struct State: Equatable {
        let appVersion: String

        @Presents
        var destination: Destination.State?

        var documentImport = DocumentImportReducer.State()

        var path = StackState<Path.State>()

        var permissions: ServerPermissions

        let server: Server

        public init(
            server: Server
        ) {
            self.appVersion = Dependency(\.getAppVersion.execute).wrappedValue()
            self.server = server
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.documentImport, action: \.documentImport) {
            DocumentImportReducer()
        }
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .importButtonTapped:
                    return .send(.documentImport(.view(.importButtonTapped)))
                case .scanButtonTapped:
                    return .send(.documentImport(.view(.scanButtonTapped)))
                }
            case let .path(.element(_, action: .licenseList(.view(.licenseSelected(license))))):
                state.path.append(.license(license))
                return .none
            case .binding, .destination, .documentImport, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}

extension SettingListReducer.Destination.State: Equatable {}
extension SettingListReducer.Path.State: Equatable {}
