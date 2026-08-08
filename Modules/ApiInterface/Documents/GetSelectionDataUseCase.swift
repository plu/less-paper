import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetSelectionDataUseCase: Sendable {

    public var execute: @Sendable (
        _ input: GetSelectionDataInput,
        _ server: Server
    ) async throws -> GetSelectionDataOutput
}

extension GetSelectionDataUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getSelectionData: GetSelectionDataUseCase {
        get { self[GetSelectionDataUseCase.self] }
        set { self[GetSelectionDataUseCase.self] = newValue }
    }
}
