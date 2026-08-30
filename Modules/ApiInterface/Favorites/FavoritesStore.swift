import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct FavoritesStore: Sendable {

    public var deleteAll: @Sendable (_ server: Server) async throws -> Void

    public var deletePDF: @Sendable (_ id: Document.Id, _ server: Server) async throws -> Void

    public var pdfURL: @Sendable (_ id: Document.Id, _ server: Server) -> URL = { _, _ in
        URL(filePath: NSTemporaryDirectory())
    }

    public var totalByteCount: @Sendable (_ server: Server) async -> Int = { _ in 0 }

    public var writePDF: @Sendable (_ data: Data, _ id: Document.Id, _ server: Server) async throws -> Int
}

extension FavoritesStore: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var favoritesStore: FavoritesStore {
        get { self[FavoritesStore.self] }
        set { self[FavoritesStore.self] = newValue }
    }
}
