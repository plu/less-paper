import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct ApiVersionRepository: Sendable {

    var getAdvertisedApiVersion: @Sendable (
        _ server: Server
    ) async throws -> Int?
}

extension ApiVersionRepository: TestDependencyKey {
    static let previewValue = Self(
        getAdvertisedApiVersion: { _ in ApiVersion.clientMaximum }
    )

    static let testValue = Self(
        getAdvertisedApiVersion: { _ in ApiVersion.clientMaximum }
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
        getAdvertisedApiVersion: getAdvertisedApiVersion(server:)
    )
}

private extension ApiVersionRepository {

    // ApiVersionMiddleware only sets X-Api-Version for authenticated users, so the probe has to hit
    // an endpoint that actually authenticates — /api/token/ would always come back bare.
    static func getAdvertisedApiVersion(
        server: Server
    ) async throws -> Int? {
        let response = try await APIClient
            .client(server: server)
            .send(Request<GetUISettingsOutput>(
                path: "/api/ui_settings/",
                method: .get
            ))

        guard let httpResponse = response.response as? HTTPURLResponse,
              let header = httpResponse.value(forHTTPHeaderField: "X-Api-Version")
        else {
            return nil
        }
        return Int(header)
    }
}
