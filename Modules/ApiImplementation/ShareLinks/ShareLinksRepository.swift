import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct ShareLinksRepository: Sendable {

    var createShareLink: @Sendable (
        _ input: CreateShareLinkInput,
        _ server: Server
    ) async throws -> ShareLink

    var deleteShareLink: @Sendable (
        _ id: ShareLink.Id,
        _ server: Server
    ) async throws -> Void

    var getShareLinks: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [ShareLink]
}

extension ShareLinksRepository: TestDependencyKey {

    static let previewValue = Self(
        createShareLink: { _, _ in .testValue() },
        deleteShareLink: { _, _ in },
        getShareLinks: { _, _ in [.testValue()] }
    )

    static let testValue = Self(
        createShareLink: { _, _ in .testValue() },
        deleteShareLink: { _, _ in },
        getShareLinks: { _, _ in [.testValue()] }
    )
}

extension DependencyValues {

    var shareLinksRepository: ShareLinksRepository {
        get { self[ShareLinksRepository.self] }
        set { self[ShareLinksRepository.self] = newValue }
    }
}

extension ShareLinksRepository: DependencyKey {
    static let liveValue = Self(
        createShareLink: createShareLink(input:server:),
        deleteShareLink: deleteShareLink(id:server:),
        getShareLinks: getShareLinks(documentId:server:)
    )
}

private extension ShareLinksRepository {

    static func createShareLink(
        input: CreateShareLinkInput,
        server: Server
    ) async throws -> ShareLink {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/share_links/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteShareLink(
        id: ShareLink.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(Request<Void>(
                path: "/api/share_links/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getShareLinks(
        documentId: Document.Id,
        server: Server
    ) async throws -> [ShareLink] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/share_links/",
                method: .get
            ))
            .value
    }
}
