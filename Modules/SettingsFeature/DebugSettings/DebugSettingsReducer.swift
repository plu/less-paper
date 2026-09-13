#if DEBUG
import ApiInterface
import Components
import ComposableArchitecture

// Simulator-only tooling for the tip invitation, whose gate needs 60 days of tenure and 15 distinct
// days of use and so cannot be reached by waiting during development.
@Reducer
public struct DebugSettingsReducer {

    @CasePathable
    public enum Action: ViewAction {

        case snapshotLoaded(TipInvitationDebug.Snapshot)

        case view(View)

        public enum View {
            case clearAnsweredButtonTapped
            case makeEligibleButtonTapped
            case onAppear
            case resetButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        var snapshot: TipInvitationDebug.Snapshot?

        public init(snapshot: TipInvitationDebug.Snapshot? = nil) {
            self.snapshot = snapshot
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .snapshotLoaded(snapshot):
                state.snapshot = snapshot
                return .none

            case .view(.clearAnsweredButtonTapped):
                TipInvitationDebug.clearSettled()
                return .runReadTipInvitationDebug()

            case .view(.makeEligibleButtonTapped):
                TipInvitationDebug.makeEligible()
                return .runReadTipInvitationDebug()

            // Re-read on every appearance rather than only the first: leaving this screen to look
            // at the inbox and coming back is the whole workflow, and a stale reading would be
            // worse than none.
            case .view(.onAppear):
                return .runReadTipInvitationDebug()

            case .view(.resetButtonTapped):
                TipInvitationDebug.reset()
                return .runReadTipInvitationDebug()
            }
        }
    }

    public init() {}
}

extension Effect where Action == DebugSettingsReducer.Action {

    static func runReadTipInvitationDebug() -> Self {
        .run { send in
            await send(.snapshotLoaded(
                TipInvitationDebug.read(expectedSuiteName: AppGroup.identifier)
            ))
        }
    }
}
#endif
