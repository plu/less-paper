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

        var customFields: IdentifiedArrayOf<CustomFieldRowReducer.State>

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

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
                state.customFields.updateOrAppend(CustomFieldRowReducer.State(customField: customField, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getCustomFieldsResult(customFields):
                state.customFields = IdentifiedArray(
                    uniqueElements: customFields.map {
                        CustomFieldRowReducer.State(
                            customField: $0,
                            server: state.server
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
