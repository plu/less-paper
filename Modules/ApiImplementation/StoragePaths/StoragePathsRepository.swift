import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct StoragePathsRepository: Sendable {

    var createStoragePath: @Sendable (
        _ input: SaveStoragePathInput,
        _ server: Server
    ) async throws -> SaveStoragePathOutput

    var deleteStoragePath: @Sendable (
        _ id: StoragePath.Id,
        _ server: Server
    ) async throws -> DeleteStoragePathOutput

    var getStoragePaths: @Sendable (
        _ input: GetStoragePathsInput,
        _ server: Server
    ) async throws -> GetStoragePathsOutput

    var updateStoragePath: @Sendable (
        _ id: StoragePath.Id,
        _ input: SaveStoragePathInput,
        _ server: Server
    ) async throws -> SaveStoragePathOutput
}

extension StoragePathsRepository: TestDependencyKey {

    static let previewValue = Self(
        createStoragePath: { _, _ in .testValue() },
        deleteStoragePath: { _, _ in },
        getStoragePaths: { _, _ in .testValue(results: .previewValue) },
        updateStoragePath: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createStoragePath: { _, _ in .testValue() },
        deleteStoragePath: { _, _ in },
        getStoragePaths: { _, _ in .testValue() },
        updateStoragePath: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var storagePathsRepository: StoragePathsRepository {
        get { self[StoragePathsRepository.self] }
        set { self[StoragePathsRepository.self] = newValue }
    }
}

extension StoragePathsRepository: DependencyKey {
    static let liveValue = Self(
        createStoragePath: createStoragePath(input:server:),
        deleteStoragePath: deleteStoragePath(id:server:),
        getStoragePaths: getStoragePaths(input:server:),
        updateStoragePath: updateStoragePath(id:input:server:)
    )
}

private extension StoragePathsRepository {

    static func createStoragePath(
        input: SaveStoragePathInput,
        server: Server
    ) async throws -> SaveStoragePathOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/storage_paths/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteStoragePath(
        id: StoragePath.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/storage_paths/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getStoragePaths(
        input: GetStoragePathsInput,
        server: Server
    ) async throws -> GetStoragePathsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateStoragePath(
        id: StoragePath.Id,
        input: SaveStoragePathInput,
        server: Server
    ) async throws -> SaveStoragePathOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/storage_paths/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetStoragePathsOutput {

    init(input: GetStoragePathsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/storage_paths/",
            method: .get
        )
    }
}
