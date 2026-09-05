import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct CustomFieldListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case customFieldDeleted(CustomField.Id)
        case customFields(IdentifiedActionOf<CustomFieldRowReducer>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case getCustomFieldsResult([CustomField])
        case isUpdating(id: CustomField.Id, isUpdating: Bool)
        case view(View)

        public enum View {
            case createCustomFieldButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case customFieldForm(CustomFieldFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        var searchText = ""

        var customFields: IdentifiedArrayOf<CustomFieldRowReducer.State>

        // Local only: the list is already in memory, so filtering it needs no request and works
        // offline. localizedCaseInsensitiveContains rather than lowercased().contains, matching the
        // filter sheets - the latter is wrong for locales whose case folding is not one-to-one.
        var visibleCustomFields: IdentifiedArrayOf<CustomFieldRowReducer.State> {
            guard !searchText.isEmpty else {
                return customFields
            }
            return customFields.filter {
                $0.customField.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        var permissions: ServerPermissions

        let server: Server

        public init(
            customFields: IdentifiedArrayOf<CustomFieldRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.customFields = customFields
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
            permissions = ServerPermissions(server: server)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .customFieldDeleted(id):
                state.customFields.remove(id: id)
                return .none
            case let .customFields(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteCustomField:
                    return .runDeleteCustomField(
                        id: id,
                        server: state.server
                    )
                case .editCustomField:
                    state.destination = .customFieldForm(CustomFieldFormReducer.State(
                        customField: state.customFields[id: id]?.customField,
                        server: state.server
                    ))
                    return .none
                }
            case let .destination(.presented(.customFieldForm(.delegate(.customFieldSaved(customField))))):
                state.destination = nil
                state.customFields.updateOrAppend(CustomFieldRowReducer.State(server: state.server, customField: customField))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getCustomFieldsResult(customFields):
                state.customFields = IdentifiedArray(
                    uniqueElements: customFields.map {
                        CustomFieldRowReducer.State(
                            server: state.server,
                            customField: $0
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.customFields[id: id]?.isUpdating = isUpdating
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .createCustomFieldButtonTapped:
                    state.destination = .customFieldForm(CustomFieldFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetCustomFields(server: state.server)
                }
            case .binding, .customFields, .destination:
                return .none
            }
        }
        .forEach(\.customFields, action: \.customFields) { CustomFieldRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.customFields.sort {
                $0.customField.name.compare(
                    $1.customField.name,
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

extension CustomFieldListReducer.Destination.State: Equatable {}
