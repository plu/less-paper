import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct TagListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case isUpdating(id: Tag.Id, isUpdating: Bool)
        case getTagsResult([Tag])
        case tagDeleted(Tag.Id)
        case tags(IdentifiedActionOf<TagRowReducer>)
        case view(View)

        public enum View {
            case createTagButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case tagForm(TagFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        var permissions: ServerPermissions

        var searchText = ""

        var tags: IdentifiedArrayOf<TagRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visibleTags: IdentifiedArrayOf<TagRowReducer.State> {
            guard !searchText.isEmpty else {
                return tags
            }
            return tags.filter { $0.tag.name.localizedCaseInsensitiveContains(searchText) }
        }

        public init(
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server,
            tags: IdentifiedArrayOf<TagRowReducer.State> = []
        ) {
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
            self.tags = tags
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .destination(.presented(.tagForm(.delegate(.tagSaved(tag))))):
                state.destination = nil
                state.tags.updateOrAppend(TagRowReducer.State(server: state.server, tag: tag))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getTagsResult(tags):
                state.tags = IdentifiedArray(
                    uniqueElements: tags.map {
                        TagRowReducer.State(
                            server: state.server,
                            tag: $0
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.tags[id: id]?.isUpdating = isUpdating
                return .none
            case let .tagDeleted(id):
                state.tags.remove(id: id)
                return .none
            case let .tags(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteTag:
                    return .runDeleteTag(
                        id: id,
                        server: state.server
                    )
                case .editTag:
                    state.destination = .tagForm(TagFormReducer.State(
                        server: state.server,
                        tag: state.tags[id: id]?.tag
                    ))
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .createTagButtonTapped:
                    state.destination = .tagForm(TagFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetTags(server: state.server)
                }
            case .binding, .destination, .tags:
                return .none
            }
        }
        .forEach(\.tags, action: \.tags) { TagRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.tags.sort {
                $0.tag.name.compare(
                    $1.tag.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
            return .none
        }
    }

    public init() {}
}

extension TagListReducer.Destination.State: Equatable {}
