import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
public struct LicenseListReducer: Reducer, Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {

        var licenses: [License]

        public init() {
            licenses = Dependency(\.licenseLoader).wrappedValue.load()
        }
    }

    public enum Action: Equatable, Sendable, ViewAction {
        case view(View)

        public enum View: Equatable, Sendable {
            case licenseSelected(License)
        }
    }

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }

    public init() {}
}
