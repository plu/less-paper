import ApiInterface
import ComposableArchitecture

extension Effect where Action == CertificateApprovalReducer.Action {

    static func runCertificateApprovalObserver() -> Self {
        .run { send in
            @Dependency(\.certificateApprovalChannel)
            var channel

            for await event in channel {
                switch event {
                case let .request(request):
                    await send(.certificateApprovalRequest(request))
                case let .response(request, approved):
                    await send(.certificateApprovalResponse(request, approved))
                }
            }
        }
    }
}
