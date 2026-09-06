import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

public struct ServerVersions: Equatable, Sendable {

    public let apiVersion: Int?

    public let paperlessVersion: String?

    public init(apiVersion: Int?, paperlessVersion: String?) {
        self.apiVersion = apiVersion
        self.paperlessVersion = paperlessVersion
    }
}

@DependencyClient
struct ApiVersionRepository: Sendable {

    var getServerVersions: @Sendable (
        _ server: Server
    ) async throws -> ServerVersions
}

extension ApiVersionRepository: TestDependencyKey {
    static let previewValue = Self(
        getServerVersions: { _ in ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: "3.0.5") }
    )

    static let testValue = Self(
        getServerVersions: { _ in ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: "3.0.5") }
    )
}

extension DependencyValues {

    var apiVersionRepository: ApiVersionRepository {
        get { self[ApiVersionRepository.self] }
        set { self[ApiVersionRepository.self] = newValue }
    }
}

extension ApiVersionRepository: DependencyKey {
    static let liveValue = Self(
        getServerVersions: getServerVersions(server:)
    )
}

private extension ApiVersionRepository {

    // ApiVersionMiddleware only sets X-Api-Version for authenticated users, so the probe has to hit
    // an endpoint that actually authenticates — /api/token/ would always come back bare. It also
    // has to ask without naming a version, because a server that rejects the guess answers 406 and
    // that response carries no X-Api-Version at all.
    static func getServerVersions(
        server: Server
    ) async throws -> ServerVersions {
        let response = try await APIClient
            .client(server: server, sendsApiVersion: false)
            .send(Request<GetUISettingsOutput>(
                path: "/api/ui_settings/",
                method: .get
            ))

        guard let httpResponse = response.response as? HTTPURLResponse else {
            return ServerVersions(apiVersion: nil, paperlessVersion: nil)
        }
        return ServerVersions(
            apiVersion: httpResponse.value(forHTTPHeaderField: "X-Api-Version").flatMap(Int.init),
            paperlessVersion: httpResponse.value(forHTTPHeaderField: "X-Version")
        )
    }
}
