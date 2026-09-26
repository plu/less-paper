import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct HistoryRepository: Sendable {

    var getHistory: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [AuditLogEntry]
}

extension HistoryRepository: TestDependencyKey {

    static let previewValue = Self(
        getHistory: { _, _ in [.testValue()] }
    )

    static let testValue = Self(
        getHistory: { _, _ in [.testValue()] }
    )
}

extension DependencyValues {

    var historyRepository: HistoryRepository {
        get { self[HistoryRepository.self] }
        set { self[HistoryRepository.self] = newValue }
    }
}

extension HistoryRepository: DependencyKey {
    static let liveValue = Self(
        getHistory: getHistory(documentId:server:)
    )
}

private extension HistoryRepository {

    static func getHistory(
        documentId: Document.Id,
        server: Server
    ) async throws -> [AuditLogEntry] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/history/",
                method: .get
            ))
            .value
    }
}
