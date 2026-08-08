import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct CorrespondentsRepository: Sendable {

    var createCorrespondent: @Sendable (
        _ input: SaveCorrespondentInput,
        _ server: Server
    ) async throws -> SaveCorrespondentOutput

    var deleteCorrespondent: @Sendable (
        _ id: Correspondent.Id,
        _ server: Server
    ) async throws -> DeleteCorrespondentOutput

    var getCorrespondents: @Sendable (
        _ input: GetCorrespondentsInput,
        _ server: Server
    ) async throws -> GetCorrespondentsOutput

    var updateCorrespondent: @Sendable (
        _ id: Correspondent.Id,
        _ input: SaveCorrespondentInput,
        _ server: Server
    ) async throws -> SaveCorrespondentOutput
}

extension CorrespondentsRepository: TestDependencyKey {

    static let previewValue = Self(
        createCorrespondent: { _, _ in .testValue() },
        deleteCorrespondent: { _, _ in },
        getCorrespondents: { _, _ in .testValue(results: .previewValue) },
        updateCorrespondent: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createCorrespondent: { _, _ in .testValue() },
        deleteCorrespondent: { _, _ in },
        getCorrespondents: { _, _ in .testValue() },
        updateCorrespondent: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var correspondentsRepository: CorrespondentsRepository {
        get { self[CorrespondentsRepository.self] }
        set { self[CorrespondentsRepository.self] = newValue }
    }
}

extension CorrespondentsRepository: DependencyKey {
    static let liveValue = Self(
        createCorrespondent: createCorrespondent(input:server:),
        deleteCorrespondent: deleteCorrespondent(id:server:),
        getCorrespondents: getCorrespondents(input:server:),
        updateCorrespondent: updateCorrespondent(id:input:server:)
    )
}

private extension CorrespondentsRepository {

    static func createCorrespondent(
        input: SaveCorrespondentInput,
        server: Server
    ) async throws -> SaveCorrespondentOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/correspondents/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteCorrespondent(
        id: Correspondent.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/correspondents/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getCorrespondents(
        input: GetCorrespondentsInput,
        server: Server
    ) async throws -> GetCorrespondentsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateCorrespondent(
        id: Correspondent.Id,
        input: SaveCorrespondentInput,
        server: Server
    ) async throws -> SaveCorrespondentOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/correspondents/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetCorrespondentsOutput {

    init(input: GetCorrespondentsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/correspondents/",
            method: .get
        )
    }
}
