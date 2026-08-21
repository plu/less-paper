import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct SavedViewsRepository: Sendable {

    var createSavedView: @Sendable (
        _ input: SaveSavedViewInput,
        _ server: Server
    ) async throws -> SaveSavedViewOutput

    var deleteSavedView: @Sendable (
        _ id: SavedView.Id,
        _ server: Server
    ) async throws -> DeleteSavedViewOutput

    var getSavedViews: @Sendable (
        _ input: GetSavedViewsInput,
        _ server: Server
    ) async throws -> GetSavedViewsOutput

    var setSavedViewVisibility: @Sendable (
        _ id: SavedView.Id,
        _ input: SetSavedViewVisibilityInput,
        _ server: Server
    ) async throws -> SaveSavedViewOutput

    var updateSavedView: @Sendable (
        _ id: SavedView.Id,
        _ input: SaveSavedViewInput,
        _ server: Server
    ) async throws -> SaveSavedViewOutput
}

extension SavedViewsRepository: TestDependencyKey {

    static let previewValue = Self(
        createSavedView: { _, _ in .testValue() },
        deleteSavedView: { _, _ in },
        getSavedViews: { _, _ in .testValue(results: .previewValue) },
        setSavedViewVisibility: { _, _, _ in .testValue() },
        updateSavedView: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createSavedView: { _, _ in .testValue() },
        deleteSavedView: { _, _ in },
        getSavedViews: { _, _ in .testValue() },
        setSavedViewVisibility: { _, _, _ in .testValue() },
        updateSavedView: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var savedViewsRepository: SavedViewsRepository {
        get { self[SavedViewsRepository.self] }
        set { self[SavedViewsRepository.self] = newValue }
    }
}

extension SavedViewsRepository: DependencyKey {
    static let liveValue = Self(
        createSavedView: createSavedView(input:server:),
        deleteSavedView: deleteSavedView(id:server:),
        getSavedViews: getSavedViews(input:server:),
        setSavedViewVisibility: setSavedViewVisibility(id:input:server:),
        updateSavedView: updateSavedView(id:input:server:)
    )
}

private extension SavedViewsRepository {

    static func createSavedView(
        input: SaveSavedViewInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/saved_views/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteSavedView(
        id: SavedView.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/saved_views/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getSavedViews(
        input: GetSavedViewsInput,
        server: Server
    ) async throws -> GetSavedViewsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func setSavedViewVisibility(
        id: SavedView.Id,
        input: SetSavedViewVisibilityInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/saved_views/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }

    static func updateSavedView(
        id: SavedView.Id,
        input: SaveSavedViewInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/saved_views/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetSavedViewsOutput {

    init(input: GetSavedViewsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/saved_views/",
            method: .get
        )
    }
}
