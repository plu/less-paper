import Components
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct SwipeActionSettingsReducer: Sendable {

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
            case actionTapped(edge: Edge, action: DocumentSwipeAction)
            case resetButtonTapped
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case let .actionTapped(edge: edge, action: action):
                    state.$settings.withLock { settings in
                        settings.toggle(action, on: edge)
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
        on edge: SwipeActionSettingsReducer.Edge
    ) {
        var actions = self[edge]
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
        self[edge] = actions
    }

    subscript(edge: SwipeActionSettingsReducer.Edge) -> [DocumentSwipeAction] {
        get {
            switch edge {
            case .leading:
                leading
            case .trailing:
                trailing
            }
        }
        set {
            switch edge {
            case .leading:
                leading = newValue
            case .trailing:
                trailing = newValue
            }
        }
    }
}
