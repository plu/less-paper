import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeletePdfPasswordUseCase: Sendable {

    public var execute: @Sendable (
        _ id: String
    ) async throws -> Void
}

extension DeletePdfPasswordUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deletePdfPassword: DeletePdfPasswordUseCase {
        get { self[DeletePdfPasswordUseCase.self] }
        set { self[DeletePdfPasswordUseCase.self] = newValue }
    }
}
