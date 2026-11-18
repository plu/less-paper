@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct ShareLinkUseCaseTests {

    @Test
    func getShareLinks_forwardsToRepository() async throws {
        let documentIdReceived = LockIsolated<Document.Id?>(nil)
        try await withDependencies {
            $0.shareLinksRepository.getShareLinks = { documentId, _ in
                documentIdReceived.setValue(documentId)
                return [.testValue()]
            }
        } operation: {
            let links = try await GetShareLinksUseCase.liveValue.execute(
                7,
                .testValue()
            )

            #expect(documentIdReceived.value == 7)
            #expect(links == [.testValue()])
        }
    }

    @Test
    func createShareLink_forwardsToRepository() async throws {
        let inputReceived = LockIsolated<CreateShareLinkInput?>(nil)
        try await withDependencies {
            $0.shareLinksRepository.createShareLink = { input, _ in
                inputReceived.setValue(input)
                return .testValue()
            }
        } operation: {
            let input = CreateShareLinkInput.testValue(document: 7, fileVersion: .original)
            let link = try await CreateShareLinkUseCase.liveValue.execute(
                input,
                .testValue()
            )

            #expect(inputReceived.value == input)
            #expect(link == .testValue())
        }
    }

    @Test
    func deleteShareLink_forwardsToRepository() async throws {
        let idReceived = LockIsolated<ShareLink.Id?>(nil)
        try await withDependencies {
            $0.shareLinksRepository.deleteShareLink = { id, _ in
                idReceived.setValue(id)
            }
        } operation: {
            try await DeleteShareLinkUseCase.liveValue.execute(
                3,
                .testValue()
            )

            #expect(idReceived.value == 3)
        }
    }
}
