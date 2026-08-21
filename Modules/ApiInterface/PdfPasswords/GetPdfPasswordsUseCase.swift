import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetPdfPasswordsUseCase: Sendable {

    public var execute: @Sendable () async throws -> [PdfPassword]
}

extension GetPdfPasswordsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { [.testValue()] }
    )

    public static let testValue = Self(
        execute: { [] }
    )
}

public extension DependencyValues {
    var getPdfPasswords: GetPdfPasswordsUseCase {
        get { self[GetPdfPasswordsUseCase.self] }
        set { self[GetPdfPasswordsUseCase.self] = newValue }
    }
}
