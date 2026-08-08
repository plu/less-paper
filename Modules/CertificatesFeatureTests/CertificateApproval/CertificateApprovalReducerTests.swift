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
}
