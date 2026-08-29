import ApiInterface
import CertificatesFeature
import Combine
import Components
import ComposableArchitecture
import ForwardAuthFeature
import Foundation
import ServersFeature
import TipsFeature

@Reducer
public struct AppReducer {

    public enum Action {
        case bootstrap
        case certificateApproval(CertificateApprovalReducer.Action)
        case didBecomeActive
        case forwardAuth(ForwardAuthReducer.Action)
        case main(MainReducer.Action)
        case selectedServerChanged(Server?)
        case serverList(ServerListReducer.Action)
        case tipReceived(Tip)
    }

    @ObservableState
    public struct State: Equatable {

        var certificateApproval = CertificateApprovalReducer.State()

        var forwardAuth = ForwardAuthReducer.State()

        var main: MainReducer.State?

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
                    return .runUpdateCache(server: server)
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
