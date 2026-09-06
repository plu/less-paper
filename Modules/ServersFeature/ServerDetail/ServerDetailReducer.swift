import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing

@Reducer
public struct ServerDetailReducer: Sendable {

    public enum Action: ViewAction {
        case refreshFailed
        case statisticsLoaded(GetStatisticsOutput)
        case view(View)

        public enum View {
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        let server: Server

        // Held rather than snapshotted so the screen updates itself as the refresh lands: a nested
        // @Shared inside @ObservableState notifies observation.
        @Shared var apiVersion: Int?
        @Shared var correspondents: IdentifiedArrayOf<Correspondent>
        @Shared var currentUser: User?
        @Shared var customFields: IdentifiedArrayOf<CustomField>
        @Shared var documentTypes: IdentifiedArrayOf<DocumentType>
        @Shared var groups: IdentifiedArrayOf<Group>
        @Shared var paperlessVersion: String?
        @Shared var permissions: [Permission]?
        @Shared var savedViews: IdentifiedArrayOf<SavedView>
        @Shared var storagePaths: IdentifiedArrayOf<StoragePath>
        @Shared var tags: IdentifiedArrayOf<Tag>
        @Shared var users: IdentifiedArrayOf<User>

        // Not cached anywhere: GetStatisticsUseCase keeps only the inbox counts.
        var statistics: GetStatisticsOutput?

        var isRefreshing = false

        // A failed refresh leaves every cached value alone and says so quietly. It must never
        // replace the screen - the last known numbers are still the best answer available.
        var refreshFailed = false

        public init(server: Server) {
            self.server = server
            _apiVersion = Shared(wrappedValue: nil, .apiVersion(server))
            _paperlessVersion = Shared(wrappedValue: nil, .paperlessVersion(server))
            _currentUser = Shared(wrappedValue: nil, .currentUser(server))
            _permissions = Shared(wrappedValue: nil, .permissions(server))
            _correspondents = Shared(wrappedValue: [], .correspondents(server))
            _customFields = Shared(wrappedValue: [], .customFields(server))
            _documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            _groups = Shared(wrappedValue: [], .groups(server))
            _savedViews = Shared(wrappedValue: [], .savedViews(server))
            _storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            _tags = Shared(wrappedValue: [], .tags(server))
            _users = Shared(wrappedValue: [], .users(server))
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshFailed:
                // Cached values stay exactly as they are.
                state.isRefreshing = false
                state.refreshFailed = true
                return .none
            case let .statisticsLoaded(statistics):
                state.statistics = statistics
                state.isRefreshing = false
                return .none
            case .view(.onAppear):
                state.isRefreshing = true
                state.refreshFailed = false
                return .runRefresh(server: state.server)
            }
        }
    }

    public init() {}
}
