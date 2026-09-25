import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct OfflineStore: Sendable {

    public var deleteAll: @Sendable (_ server: Server) async throws -> Void

    public var deletePDF: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void

    public var pdfURL: @Sendable (_ id: Document.Id, _ server: Server) -> URL = { _, _ in
        URL(filePath: NSTemporaryDirectory())
    }

    public var totalByteCount: @Sendable (_ server: Server) async -> Int = { _ in 0 }

    public var writePDF: @Sendable (_ data: Data, _ id: Document.Id, _ server: Server) async throws -> Int
}

extension OfflineStore: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var offlineStore: OfflineStore {
        get { self[OfflineStore.self] }
        set { self[OfflineStore.self] = newValue }
    }
}
