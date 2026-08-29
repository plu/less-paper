import ApiInterface
import CertificatesFeature
import Combine
import Components
import ComposableArchitecture
import ForwardAuthFeature
import Foundation
import ServersFeature
import TipsFeature

// A link that has been resolved to a server but cannot be acted on yet, because the selected server
// has to change first and MainReducer.State is rebuilt asynchronously when it does. A URL arriving
// at cold start is the same shape, so both wait here rather than in two special cases.
struct PendingDeepLink: Equatable {

    let route: DeepLink.Route

    let server: Server
}

@Reducer
public struct AppReducer {

    @CasePathable
    public enum Action {
        case applyPendingLink
        case bootstrap
        case certificateApproval(CertificateApprovalReducer.Action)
        case didBecomeActive
        case forwardAuth(ForwardAuthReducer.Action)
        case main(MainReducer.Action)
        case openURL(URL)
        case selectedServerChanged(Server?)
        case serverList(ServerListReducer.Action)
        case tipReceived(Tip)
    }

    @ObservableState
    public struct State: Equatable {

        var certificateApproval = CertificateApprovalReducer.State()

        var forwardAuth = ForwardAuthReducer.State()

        var main: MainReducer.State?

        var pendingLink: PendingDeepLink?

        var serverList = ServerListReducer.State()

        public init(
            main: MainReducer.State? = nil
        ) {
            self.main = main
        }
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.serverList, action: \.serverList) {
            ServerListReducer()
        }
        Scope(state: \.certificateApproval, action: \.certificateApproval) {
            CertificateApprovalReducer()
        }
        Scope(state: \.forwardAuth, action: \.forwardAuth) {
            ForwardAuthReducer()
        }
        Reduce { state, action in
            switch action {
            case .applyPendingLink:
                guard let pending = state.pendingLink,
                      state.main?.server.id == pending.server.id
                else {
                    return .none
                }
                state.pendingLink = nil
                switch pending.route {
                case let .documentDetail(id):
                    state.main?.selectedTab = .documents
                    return .send(.main(.documentList(.openDocument(id))))
                }
            case let .openURL(url):
                // A URL this app cannot read says nothing the user could act on, so it is dropped
                // rather than reported. atlp:// is also the OIDC callback scheme, and that callback
                // is consumed by ASWebAuthenticationSession rather than arriving here.
                guard let link = DeepLink(url: url) else {
                    return .none
                }

                @Shared(.servers)
                var servers

                guard let server = servers.first(where: { link.resolves(to: $0) }) else {
                    return .toast(DeepLinkError.serverNotFound(host: link.host))
                }

                state.pendingLink = PendingDeepLink(route: link.route, server: server)

                if state.main?.server.id == server.id {
                    return .send(.applyPendingLink)
                }

                // Changing the selection rebuilds main for that server, and the link is applied
                // from selectedServerChanged once it has been.
                @Shared(.selectedServer)
                var selectedServer

                $selectedServer.withLock { $0 = server }

                return .none
            case .bootstrap:
                return .runSelectedServerObserver()
                    .merge(with: .run { send in
                        await send(.certificateApproval(.bootstrap))
                    })
                    .merge(with: .run { send in
                        await send(.forwardAuth(.bootstrap))
                    })
                    .merge(with: .runTipObserver())
            case .didBecomeActive:
                guard let server = state.main?.server else {
                    return .none
                }
                return .runRefreshStatistics(server: server)
            case .selectedServerChanged(let server):
                if let server {
                    state.main = MainReducer.State(server: server)
                    let updateCache = Effect<Action>.runUpdateCache(server: server)
                    guard state.pendingLink != nil else {
                        return updateCache
                    }
                    return updateCache.merge(with: .send(.applyPendingLink))
                } else {
                    state.main = nil
                    state.serverList = ServerListReducer.State()
                    return .none
                }
            case .certificateApproval, .forwardAuth, .main, .serverList:
                return .none
            case .tipReceived:
                return .toast(Toast.success(String(localized: .tipThankYou)))
            }
        }
        .ifLet(\.main, action: \.main) {
            MainReducer()
        }
    }

    public init() {}
}
