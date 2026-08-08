import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct CopyFilesUseCase: Sendable {

    var execute: @Sendable (
        _ files: [URL]
    ) async throws -> [URL]
}

extension CopyFilesUseCase: TestDependencyKey {

    static let previewValue = Self()

    static let testValue = Self()
}

extension DependencyValues {
    var copyFiles: CopyFilesUseCase {
        get { self[CopyFilesUseCase.self] }
        set { self[CopyFilesUseCase.self] = newValue }
    }
}

extension CopyFilesUseCase: DependencyKey {
    static let liveValue = Self(
        execute: execute(files:)
    )
}

private extension CopyFilesUseCase {

    static func execute(
        files: [URL]
    ) async throws -> [URL] {
        try files.compactMap { url in
            guard url.startAccessingSecurityScopedResource() else {
                return url
            }

            defer { url.stopAccessingSecurityScopedResource() }

            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let temporaryFile = temporaryDirectory.appendingPathComponent(url.lastPathComponent)

            if FileManager.default.fileExists(atPath: temporaryFile.path) {
                try FileManager.default.removeItem(at: temporaryFile)
            }

            try FileManager.default.copyItem(at: url, to: temporaryFile)
            return temporaryFile
        }
    }
}
