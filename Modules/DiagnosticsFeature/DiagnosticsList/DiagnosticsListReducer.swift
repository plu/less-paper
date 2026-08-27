import ComposableArchitecture
import Dependencies
import Foundation
import Logging

@Reducer
public struct DiagnosticsListReducer: Reducer, Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {

        var entries: [LogEntry] = []
        var fileURLs: [URL] = []
        var isLoaded = false

        public init(
            entries: [LogEntry] = [],
            fileURLs: [URL] = [],
            isLoaded: Bool = false
        ) {
            self.entries = entries
            self.fileURLs = fileURLs
            self.isLoaded = isLoaded
        }
    }

    public enum Action: Sendable, ViewAction {
        case entriesLoaded(entries: [LogEntry], fileURLs: [URL])
        case view(View)

        public enum View: Equatable, Sendable {
            case clearButtonTapped
            case onAppear
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .entriesLoaded(entries, fileURLs):
                state.entries = entries
                state.fileURLs = fileURLs
                state.isLoaded = true
                return .none
            case .view(.clearButtonTapped):
                return .run { send in
                    guard await clearLogConfirmation.present() else {
                        return
                    }
                    await log.clear()
                    await send(.entriesLoaded(entries: [], fileURLs: []))
                }
            case .view(.onAppear):
                // Reloaded on every appearance rather than observed: the log is written from
                // everywhere, and a screen that shows a stale copy of it is worse than one that
                // takes a moment.
                return .run { send in
                    await send(.entriesLoaded(
                        entries: log.entries(),
                        fileURLs: log.fileURLs()
                    ))
                }
            }
        }
    }

    public init() {}

    @Dependency(\.clearLogConfirmation)
    private var clearLogConfirmation

    @Dependency(\.log)
    private var log
}
