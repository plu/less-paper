@testable import CertificatesFeature

import ApiInterface
import AsyncAlgorithms
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport
import X509

@MainActor
@Suite(
    .dependencies()
)
struct CertificateApprovalReducerTests {
    @Test
    func test_multipleRequests() async throws {
        let channel = AsyncChannel<CertificateApprovalEvent>()
        let request1 = CertificateApprovalRequest.testValue()
        let request2 = CertificateApprovalRequest.testValue()
        let request3 = CertificateApprovalRequest.testValue()
        let request4 = CertificateApprovalRequest.testValue()
        let popupPresentationCount = LockIsolated<Int>(0)
        let store = TestStore(
            initialState: CertificateApprovalReducer.State(),
            reducer: { CertificateApprovalReducer() },
            withDependencies: {
                $0.approveCertificate.execute = { request in
                    if request.id == request2.id {
                        return true
                    }
                    return false
                }
                $0.certificateApprovalChannel = channel
                $0.popupPresenter.present = { _ in popupPresentationCount.setValue(popupPresentationCount.value + 1) }
            }
        )
        let bootstrap = await store.send(.bootstrap)

        await channel.send(.request(request1))

        await store.receive(\.certificateApprovalRequest) {
            $0.requests = [request1]
        }

        await store.receive(\.processNextApprovalRequest) {
            $0.presentedRequest = request1
            $0.requests = []
        }

        await channel.send(.request(request2))

        await store.receive(\.certificateApprovalRequest) {
            $0.requests = [request2]
        }

        await store.receive(\.processNextApprovalRequest)

        await channel.send(.request(request3))

        await store.receive(\.certificateApprovalRequest) {
            $0.requests = [request2, request3]
        }

        await store.receive(\.processNextApprovalRequest)

        await channel.send(.request(request4))

        await store.receive(\.certificateApprovalRequest) {
            $0.requests = [request2, request3, request4]
        }

        await store.receive(\.processNextApprovalRequest)

        await channel.send(.response(request1, false))

        await store.receive(\.certificateApprovalResponse) {
            $0.presentedRequest = nil
        }

        await store.receive(\.processNextApprovalRequest) {
            $0.presentedRequest = request2
            $0.requests = [request3, request4]
        }

        await channel.send(.response(request2, true))

        await store.receive(\.certificateApprovalResponse) {
            $0.presentedRequest = nil
            $0.$trustedCertificates.withLock {
                $0 = [
                    TrustedCertificate(
                        issuer: "ST=Delaware,CN=Proxyman CA (4 Jun 2025\\, pbook.local\\, AA94759F),O=Proxyman LLC,L=Wilmington,C=US",
                        serialNumber: "56:1d:1e:de"
                    )
                ]
            }
        }

        await store.receive(\.processNextApprovalRequest) {
            $0.requests = [request4]
        }

        await store.receive(\.processNextApprovalRequest) {
            $0.requests = []
        }

        await store.receive(\.processNextApprovalRequest)

        #expect(popupPresentationCount.value == 2)

        await bootstrap.cancel()
    }

    // A challenge the reducer answers without presenting anything - here one with no certificate
    // to inspect, which is what a host with an ordinary certificate amounts to - must still pump
    // the queue. Whatever is queued behind it would otherwise wait for the next challenge to
    // arrive, and a request whose completion is never called hangs for as long as the app is
    // open. The forward-auth web view makes several hosts per login ordinary.
    @Test
    func test_requestAnsweredWithoutAPopup_stillDrainsTheQueue() async throws {
        let channel = AsyncChannel<CertificateApprovalEvent>()
        let completed = LockIsolated<[String]>([])

        func request(_ name: String, challenge: URLAuthenticationChallenge) -> CertificateApprovalRequest {
            CertificateApprovalRequest.testValue(
                challenge: challenge,
                completion: { _, _ in completed.withValue { $0.append(name) } },
                id: UUID()
            )
        }

        let presented = request("presented", challenge: .testValue())
        let first = request("first", challenge: .withoutServerTrust())
        let second = request("second", challenge: .withoutServerTrust())

        let store = TestStore(
            initialState: CertificateApprovalReducer.State(),
            reducer: { CertificateApprovalReducer() },
            withDependencies: {
                $0.certificateApprovalChannel = channel
                $0.popupPresenter.present = { _ in }
            }
        )
        store.exhaustivity = .off

        let bootstrap = await store.send(.bootstrap)

        // The first challenge is untrusted and takes the popup; the other two queue behind it.
        for approvalRequest in [presented, first, second] {
            await channel.send(.request(approvalRequest))
            await store.receive(\.certificateApprovalRequest)
            await store.receive(\.processNextApprovalRequest)
        }

        await channel.send(.response(presented, false))
        await store.receive(\.certificateApprovalResponse)
        await store.receive(\.processNextApprovalRequest)
        await store.receive(\.processNextApprovalRequest)
        await store.receive(\.processNextApprovalRequest)

        // Not just the one at the head of the queue: everything behind it too.
        #expect(completed.value == ["presented", "first", "second"])

        await bootstrap.cancel()
    }
}

private extension URLAuthenticationChallenge {

    // A challenge with nothing to inspect, which is the shape the reducer answers with
    // performDefaultHandling and no popup.
    static func withoutServerTrust() -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: NoServerTrustProtectionSpace(
                host: "assets.example.com",
                port: 443,
                protocol: "https",
                realm: nil,
                authenticationMethod: nil
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: NoOpChallengeSender()
        )
    }
}

private final class NoServerTrustProtectionSpace: URLProtectionSpace, @unchecked Sendable {

    override var serverTrust: SecTrust? { nil }
}

private final class NoOpChallengeSender: NSObject, URLAuthenticationChallengeSender {

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}

    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
