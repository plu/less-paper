import ApiInterface
import CertificatesFeature
import Combine
import ComposableArchitecture
import Foundation
import ServersFeature

@Reducer
public struct AppReducer {

    public enum Action {
        case bootstrap
        case certificateApproval(CertificateApprovalReducer.Action)
        case main(MainReducer.Action)
        case selectedServerChanged(Server?)
        case serverList(ServerListReducer.Action)
    }

    @ObservableState
    public struct State: Equatable {

        var certificateApproval = CertificateApprovalReducer.State()

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
        Reduce { state, action in
            switch action {
            case .bootstrap:
                return .runSelectedServerObserver().merge(with: .run { send in
                    await send(.certificateApproval(.bootstrap))
                })
            case .selectedServerChanged(let server):
                if let server {
                    state.main = MainReducer.State(server: server)
                    return .runUpdateCache(server: server)
                } else {
                    state.main = nil
                    state.serverList = ServerListReducer.State()
                    return .none
                }
            case .certificateApproval, .main, .serverList:
                return .none
            }
        }
        .ifLet(\.main, action: \.main) {
            MainReducer()
        }
    }

    public init() {}
}
