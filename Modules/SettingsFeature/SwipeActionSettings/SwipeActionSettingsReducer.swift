import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct SwipeActionSettingsReducer: Sendable {

    public enum Screen: Equatable, Sendable {
        case documents
        case inbox
    }

    public enum Edge: Equatable, Sendable {
        case leading
        case trailing
    }

    @ObservableState
    public struct State: Equatable {

        @Shared(.documentSwipeActions)
        var settings: DocumentSwipeActionSettings

        public init() {}
    }

    public enum Action: ViewAction {
        case view(View)

        public enum View {
            case actionTapped(screen: Screen, edge: Edge, action: DocumentSwipeAction)
            case resetButtonTapped
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case let .actionTapped(screen: screen, edge: edge, action: action):
                    state.$settings.withLock { settings in
                        settings.toggle(action, on: screen, edge: edge)
                    }
                    return .none
                case .resetButtonTapped:
                    state.$settings.withLock { $0 = .init() }
                    return .none
                }
            }
        }
    }
}

extension DocumentSwipeActionSettings {

    mutating func toggle(
        _ action: DocumentSwipeAction,
        on screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) {
        var actions = self[screen, edge]
        if let index = actions.firstIndex(of: action) {
            actions.remove(at: index)
        } else {
            // Refused rather than evicting the oldest: a tap that quietly drops an action the user
            // picked a moment ago is worse than one that does nothing.
            guard actions.count < Self.maximumActionsPerEdge else {
                return
            }
            actions.append(action)
        }
        self[screen, edge] = actions
    }

    subscript(
        screen: SwipeActionSettingsReducer.Screen,
        edge: SwipeActionSettingsReducer.Edge
    ) -> [DocumentSwipeAction] {
        get {
            switch (screen, edge) {
            case (.documents, .leading):
                documents.leading
            case (.documents, .trailing):
                documents.trailing
            case (.inbox, .leading):
                inbox.leading
            case (.inbox, .trailing):
                inbox.trailing
            }
        }
        set {
            switch (screen, edge) {
            case (.documents, .leading):
                documents.leading = newValue
            case (.documents, .trailing):
                documents.trailing = newValue
            case (.inbox, .leading):
                inbox.leading = newValue
            case (.inbox, .trailing):
                inbox.trailing = newValue
            }
        }
    }
}
