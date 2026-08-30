import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct PdfPasswordListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case error(Error)
        case getPdfPasswordsResult([PdfPassword])
        case pdfPasswordDeleted(String)
        case pdfPasswords(IdentifiedActionOf<PdfPasswordRowReducer>)
        case view(View)

        public enum View {
            case onAppear
            case onRefresh
        }
    }

    @ObservableState
    public struct State: Equatable {

        var isLoaded: Bool
        var searchText = ""

        var pdfPasswords: IdentifiedArrayOf<PdfPasswordRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visiblePdfPasswords: IdentifiedArrayOf<PdfPasswordRowReducer.State> {
            guard !searchText.isEmpty else {
                return pdfPasswords
            }
            return pdfPasswords.filter {
                $0.pdfPassword.filename.localizedCaseInsensitiveContains(searchText)
            }
        }

        public init(
            isLoaded: Bool = false,
            pdfPasswords: IdentifiedArrayOf<PdfPasswordRowReducer.State> = []
        ) {
            self.isLoaded = isLoaded
            self.pdfPasswords = pdfPasswords
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .error(error):
                return .toast(error)
            case let .getPdfPasswordsResult(pdfPasswords):
                state.isLoaded = true
                state.pdfPasswords = IdentifiedArray(
                    uniqueElements: pdfPasswords.map { PdfPasswordRowReducer.State(pdfPassword: $0) }
                )
                return .none
            case let .pdfPasswordDeleted(id):
                state.pdfPasswords.remove(id: id)
                return .none
            case let .pdfPasswords(.element(id: id, action: .delegate(.deletePdfPassword))):
                return .runDeletePdfPassword(id: id)
            case let .view(viewAction):
                switch viewAction {
                case .onAppear, .onRefresh:
                    return .runGetPdfPasswords()
                }
            case .binding, .pdfPasswords:
                return .none
            }
        }
        .forEach(\.pdfPasswords, action: \.pdfPasswords) { PdfPasswordRowReducer() }
    }

    public init() {}
}
