import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import SwiftUI
import X509

@Reducer
public struct CertificateApprovalReducer: Sendable {
    @CasePathable
    public enum Action {
        case bootstrap
        case certificateApprovalRequest(CertificateApprovalRequest)
        case certificateApprovalResponse(CertificateApprovalRequest, Bool)
        case processNextApprovalRequest
    }

    @ObservableState
    public struct State: Equatable {

        var presentedRequest: CertificateApprovalRequest?

        var requests: IdentifiedArrayOf<CertificateApprovalRequest> = []

        @Shared(.trustedCertificates)
        var trustedCertificates: IdentifiedArrayOf<TrustedCertificate>

        public init() {}
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .bootstrap:
                return .runCertificateApprovalObserver()
            case let .certificateApprovalResponse(request, approved):
                if approved, let certificate = request.challenge.firstCertificate, approveCertificate(request) {
                    _ = state.$trustedCertificates.withLock {
                        $0.updateOrAppend(
                            TrustedCertificate(
                                issuer: certificate.issuer.description,
                                serialNumber: certificate.serialNumber.description
                            )
                        )
                    }
                } else {
                    request.completion(.performDefaultHandling, nil)
                }

                state.presentedRequest = nil
                return .send(.processNextApprovalRequest)
            case let .certificateApprovalRequest(request):
                state.requests.append(request)
                return .send(.processNextApprovalRequest)
            case .processNextApprovalRequest:
                guard state.presentedRequest == nil, !state.requests.isEmpty else {
                    return .none
                }

                let request = state.requests.removeFirst()

                // Both answers below finish this request without presenting anything, so the queue
                // has to be drained rather than left where it is: nothing else pumps it until the
                // next challenge arrives, and a request whose completion is never called is a
                // network task that hangs for as long as the app is open. One challenge answered
                // without a popup - a host with an ordinary certificate - would otherwise strand
                // every challenge queued behind it. The forward-auth web view makes that ordinary:
                // an identity provider's assets come from hosts the API never talks to.
                guard let certificate = request.challenge.firstCertificate,
                      let serverTrust = request.challenge.protectionSpace.serverTrust
                else {
                    request.completion(.performDefaultHandling, nil)
                    return .send(.processNextApprovalRequest)
                }

                var error: CFError?
                let isTrusted = SecTrustEvaluateWithError(serverTrust, &error)
                if isTrusted && error == nil {
                    request.completion(.performDefaultHandling, nil)
                    return .send(.processNextApprovalRequest)
                }

                if state.trustedCertificates.contains(where: { $0.serialNumber == certificate.serialNumber.description }) {
                    _ = approveCertificate(request)
                    return .send(.processNextApprovalRequest)
                }

                state.presentedRequest = request

                return .run { _ in
                    @Dependency(\.certificateApprovalChannel)
                    var channel

                    @Dependency(\.popupPresenter)
                    var popupPresenter

                    await popupPresenter.present {
                        CertificateApprovalView(
                            issuer: certificate.issuer.description,
                            serialNumber: certificate.serialNumber.description,
                            url: request.url?.absoluteString,
                            approve: {
                                Task {
                                    await popupPresenter.dismiss()
                                    await channel.send(.response(request, true))
                                }
                            },
                            cancel: {
                                Task {
                                    await popupPresenter.dismiss()
                                    await channel.send(.response(request, false))
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    public init() {}

    @Dependency(\.approveCertificate.execute)
    private var approveCertificate
}
