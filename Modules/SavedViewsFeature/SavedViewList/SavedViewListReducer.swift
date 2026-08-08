import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct SavedViewListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case isUpdating(id: SavedView.Id, isUpdating: Bool)
        case getSavedViewsResult([SavedView])
        case savedViewDeleted(SavedView.Id)
        case savedViews(IdentifiedActionOf<SavedViewRowReducer>)
        case view(View)

        public enum View {
            case createSavedViewButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case savedViewForm(SavedViewFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        var savedViews: IdentifiedArrayOf<SavedViewRowReducer.State>

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        public init(
            savedViews: IdentifiedArrayOf<SavedViewRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.savedViews = savedViews
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .destination(.presented(.savedViewForm(.delegate(.savedViewSaved(savedView))))):
                state.destination = nil
                state.savedViews.updateOrAppend(SavedViewRowReducer.State(savedView: savedView, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getSavedViewsResult(savedViews):
                state.savedViews = IdentifiedArray(
                    uniqueElements: savedViews.map {
                        SavedViewRowReducer.State(
                            savedView: $0,
                            server: state.server
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.savedViews[id: id]?.isUpdating = isUpdating
                return .none
            case let .savedViewDeleted(id):
                state.savedViews.remove(id: id)
                return .none
            case let .savedViews(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteSavedView:
                    return .runDeleteSavedView(
                        id: id,
                        server: state.server
                    )
                case .editSavedView:
                    let savedView = state.savedViews[id: id]?.savedView
                    state.destination = .savedViewForm(SavedViewFormReducer.State(
                        id: savedView?.id,
                        input: SavedViewFormInput(savedView: savedView),
                        server: state.server
                    ))
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .createSavedViewButtonTapped:
                    state.destination = .savedViewForm(SavedViewFormReducer.State(
                        input: SavedViewFormInput(),
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetSavedViews(server: state.server)
                }
            case .binding, .destination, .savedViews:
                return .none
            }
        }
        .forEach(\.savedViews, action: \.savedViews) { SavedViewRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.savedViews.sort {
                $0.savedView.name.compare(
                    $1.savedView.name,
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

extension SavedViewListReducer.Destination.State: Equatable {}
