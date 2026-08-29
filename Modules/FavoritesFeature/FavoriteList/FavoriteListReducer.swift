import ApiInterface
import Components
import ComposableArchitecture
import DocumentsFeature
import Foundation
import Tagged

@Reducer
public struct FavoriteListReducer: Sendable {

    @Reducer
    public enum Path {
        case documentDetail(DocumentDetailReducer)

        // The whole point of reusing the detail screen: every fetch it makes is pointed at the
        // record, so it reads with no connection. These five are the whole set — the detail's own
        // download, and the four the viewer sheet's sections reach. A sixth added to that screen
        // would compile, pass every other test, and only fail offline, which is what
        // `test_theDetailScreenReadsFromTheStoreRatherThanTheNetwork` is there to catch.
        @ReducerBuilder<State, Action>
        public static var body: some ReducerOf<Self> {
            EmptyReducer()
                .ifCaseLet(\.documentDetail, action: \.documentDetail) {
                    DocumentDetailReducer()
                        .dependency(\.downloadDocument, .favoritesStore)
                        .dependency(\.getDocument, .favoritesStore)
                        .dependency(\.getDocumentMetadata, .favoritesStore)
                        .dependency(\.getDocumentsByIds, .favoritesStore)
                        .dependency(\.getNotes, .favoritesStore)
                }
        }
    }

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case favoritesChanged(IdentifiedArrayOf<FavoriteDocument>)
        case path(StackActionOf<Path>)
        case refreshResult(Result<FavoriteRefreshResult, Error>)
        case rows(IdentifiedActionOf<FavoriteRowReducer>)
        case view(View)

        public enum View {
            case onAppear
            case onDisappear
            case onRefresh
        }
    }

    @ObservableState
    public struct State: Equatable {

        var isRefreshing = false

        var path = StackState<Path.State>()

        // Stored rather than computed: `.forEach` scopes a child store out of stored state, and a
        // computed property has nothing for it to scope. Rebuilt whenever the favorites or the
        // search text move.
        var rows: IdentifiedArrayOf<FavoriteRowReducer.State> = []

        var searchText = ""

        let server: Server

        @Shared
        var favorites: IdentifiedArrayOf<FavoriteDocument>

        // The `.inMemory` cache the documents and inbox lists project their rows out of. Read-side
        // only here: a favorite carries its own copy of the document, so without this the list
        // would show the pre-edit copy for the rest of the session — a refresh runs on pull or on
        // foreground, and an in-session edit is neither.
        @Shared
        var documentCache: IdentifiedArrayOf<Document>

        public init(server: Server) {
            self.server = server
            self._favorites = Shared(wrappedValue: [], .favorites(server))
            self._documentCache = Shared(wrappedValue: [], .documents(server))
            rebuildRows()
        }

        var visibleFavorites: IdentifiedArrayOf<FavoriteDocument> {
            guard !searchText.isEmpty else {
                return favorites
            }

            let needle = searchText.lowercased()
            return favorites.filter { favorite in
                let document = displayed(favorite)
                let haystack = [
                    document.title,
                    document.content ?? "",
                    document.correspondent?.get(server)?.name ?? "",
                    document.documentType?.get(server)?.name ?? "",
                    document.storagePath?.get(server)?.name ?? "",
                ] + document.tags.compactMap { $0.get(server)?.name }

                return haystack.contains { $0.lowercased().contains(needle) }
            }
        }

        mutating func rebuildRows() {
            rows = IdentifiedArray(uniqueElements: visibleFavorites.map { favorite in
                FavoriteRowReducer.State(
                    document: reference(to: favorite),
                    favorite: favorite,
                    server: server
                )
            })
        }

        private func displayed(_ favorite: FavoriteDocument) -> Document {
            documentCache[id: favorite.id] ?? favorite.document
        }

        // The live copy when the cache has one, the stored snapshot otherwise. A cold launch and an
        // offline session get the snapshot, which is exactly when it is the only truth available.
        private func reference(to favorite: FavoriteDocument) -> Shared<Document> {
            Shared($documentCache[id: favorite.id]) ?? Shared(value: favorite.document)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchText):
                state.rebuildRows()
                return .none
            case .favoritesChanged:
                // Nothing is written back: the observer exists so a favorite removed by a swipe,
                // or added from the documents list, leaves and enters this list without waiting
                // for the next appearance.
                state.rebuildRows()
                return .none
            case let .refreshResult(result):
                state.isRefreshing = false
                state.rebuildRows()
                guard case let .failure(error) = result else {
                    return .none
                }
                return .toast(error)
            case let .rows(.element(id: id, action: .delegate(.open(favorite)))):
                state.path.append(.documentDetail(DocumentDetailReducer.State(
                    // The row's own reference, so an edit made in the detail reaches the row
                    // behind it rather than a copy of it.
                    document: state.rows[id: id]?.$document ?? Shared(value: favorite.document),
                    server: state.server
                )))
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    return .runFavoritesObserver(server: state.server)
                case .onDisappear:
                    return .cancel(id: FavoriteListCancelID.observeFavorites)
                case .onRefresh:
                    guard !state.isRefreshing else {
                        return .none
                    }
                    state.isRefreshing = true
                    return .runRefreshFavorites(server: state.server)
                }
            case .binding, .path, .rows:
                return .none
            }
        }
        .forEach(\.rows, action: \.rows) { FavoriteRowReducer() }
        .forEach(\.path, action: \.path)
    }

    public init() {}
}

extension FavoriteListReducer.Path.State: Equatable {}
