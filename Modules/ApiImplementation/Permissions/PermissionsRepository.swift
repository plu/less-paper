import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct PermissionsRepository: Sendable {

    var getPermissions: @Sendable (
        _ input: GetPermissionsInput,
        _ server: Server
    ) async throws -> GetPermissionsOutput
}

extension PermissionsRepository: TestDependencyKey {
    static let previewValue = Self(
        getPermissions: { _, _ in .testValue() }
    )

    static let testValue = Self(
        getPermissions: { _, _ in .testValue() }
    )
}

extension DependencyValues {

    var permissionsRepository: PermissionsRepository {
        get { self[PermissionsRepository.self] }
        set { self[PermissionsRepository.self] = newValue }
    }
}

extension PermissionsRepository: DependencyKey {
    static let liveValue = Self(
        getPermissions: getPermissions(input:server:)
    )
}

private extension PermissionsRepository {

    static func getPermissions(
        input: GetPermissionsInput,
        server: Server
    ) async throws -> GetPermissionsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: input.type.path,
                method: .get,
                query: [("full_perms", "true")]
            ))
            .value
    }
}
