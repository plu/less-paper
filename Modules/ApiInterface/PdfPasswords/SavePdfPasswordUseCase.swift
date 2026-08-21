import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SavePdfPasswordUseCase: Sendable {

    public var execute: @Sendable (
        _ filename: String,
        _ password: String
    ) async throws -> Void
}

extension SavePdfPasswordUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var savePdfPassword: SavePdfPasswordUseCase {
        get { self[SavePdfPasswordUseCase.self] }
        set { self[SavePdfPasswordUseCase.self] = newValue }
    }
}
