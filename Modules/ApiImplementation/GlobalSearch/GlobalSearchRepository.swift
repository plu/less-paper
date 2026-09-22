import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct GlobalSearchRepository: Sendable {

    var search: @Sendable (
        _ input: GlobalSearchInput,
        _ server: Server
    ) async throws -> GlobalSearchOutput
}

extension GlobalSearchRepository: TestDependencyKey {

    static let previewValue = Self(
        search: { _, _ in .testValue() }
    )

    static let testValue = Self(
        search: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var globalSearchRepository: GlobalSearchRepository {
        get { self[GlobalSearchRepository.self] }
        set { self[GlobalSearchRepository.self] = newValue }
    }
}

extension GlobalSearchRepository: DependencyKey {
    static let liveValue = Self(
        search: search(input:server:)
    )
}

private extension GlobalSearchRepository {

    static func search(
        input: GlobalSearchInput,
        server: Server
    ) async throws -> GlobalSearchOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }
}

private extension Request where Response == GlobalSearchOutput {

    init(input: GlobalSearchInput) {
        self.init(
            path: "/api/search/",
            method: .get,
            query: [("query", input.query)]
        )
    }
}
