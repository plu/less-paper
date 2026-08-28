import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct TrashRepository: Sendable {

    var emptyTrash: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void

    var getTrash: @Sendable (
        _ server: Server
    ) async throws -> GetTrashOutput

    var restoreDocuments: @Sendable (
        _ ids: [Document.Id],
        _ server: Server
    ) async throws -> Void
}

extension TrashRepository: TestDependencyKey {

    static let previewValue = Self(
        emptyTrash: { _, _ in },
        getTrash: { _ in .testValue() },
        restoreDocuments: { _, _ in }
    )

    static let testValue = Self(
        emptyTrash: { _, _ in },
        getTrash: { _ in .testValue() },
        restoreDocuments: { _, _ in }
    )
}

extension TrashRepository: DependencyKey {

    static let liveValue = Self(
        emptyTrash: { ids, server in
            try await perform(.empty, ids: ids, server: server)
        },
        getTrash: getTrash(server:),
        restoreDocuments: { ids, server in
            try await perform(.restore, ids: ids, server: server)
        }
    )
}

extension DependencyValues {

    var trashRepository: TrashRepository {
        get { self[TrashRepository.self] }
        set { self[TrashRepository.self] = newValue }
    }
}

private extension TrashRepository {

    /// Both operations are the same POST with a different verb, which is how the API models them.
    enum Action: String, Encodable {
        case empty
        case restore
    }

    struct Body: Encodable {
        let action: Action
        let documents: [Document.Id]
    }

    static func getTrash(server: Server) async throws -> GetTrashOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/trash/",
                method: .get
            ))
            .value
    }

    static func perform(
        _ action: Action,
        ids: [Document.Id],
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/trash/",
                method: .post,
                body: Body(action: action, documents: ids)
            ))
            .value
    }
}
