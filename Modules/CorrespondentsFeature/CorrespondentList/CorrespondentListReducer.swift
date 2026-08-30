import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct CorrespondentListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case isUpdating(id: Correspondent.Id, isUpdating: Bool)
        case getCorrespondentsResult([Correspondent])
        case correspondentDeleted(Correspondent.Id)
        case correspondents(IdentifiedActionOf<CorrespondentRowReducer>)
        case view(View)

        public enum View {
            case createCorrespondentButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case correspondentForm(CorrespondentFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        var searchText = ""

        var correspondents: IdentifiedArrayOf<CorrespondentRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visibleCorrespondents: IdentifiedArrayOf<CorrespondentRowReducer.State> {
            guard !searchText.isEmpty else {
                return correspondents
            }
            return correspondents.filter {
                $0.correspondent.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        public init(
            correspondents: IdentifiedArrayOf<CorrespondentRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.correspondents = correspondents
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .destination(.presented(.correspondentForm(.delegate(.correspondentSaved(correspondent))))):
                state.destination = nil
                state.correspondents.updateOrAppend(CorrespondentRowReducer.State(correspondent: correspondent, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getCorrespondentsResult(correspondents):
                state.correspondents = IdentifiedArray(
                    uniqueElements: correspondents.map {
                        CorrespondentRowReducer.State(
                            correspondent: $0,
                            server: state.server
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.correspondents[id: id]?.isUpdating = isUpdating
                return .none
            case let .correspondentDeleted(id):
                state.correspondents.remove(id: id)
                return .none
            case let .correspondents(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteCorrespondent:
                    return .runDeleteCorrespondent(
                        id: id,
                        server: state.server
                    )
                case .editCorrespondent:
                    state.destination = .correspondentForm(CorrespondentFormReducer.State(
                        correspondent: state.correspondents[id: id]?.correspondent,
                        server: state.server
                    ))
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .createCorrespondentButtonTapped:
                    state.destination = .correspondentForm(CorrespondentFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetCorrespondents(server: state.server)
                }
            case .binding, .destination, .correspondents:
                return .none
            }
        }
        .forEach(\.correspondents, action: \.correspondents) { CorrespondentRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.correspondents.sort {
                $0.correspondent.name.compare(
                    $1.correspondent.name,
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

extension CorrespondentListReducer.Destination.State: Equatable {}
