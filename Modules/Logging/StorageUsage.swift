import Dependencies
import DependenciesMacros
import Foundation

public struct StorageUsage: Equatable, Sendable {

    public static let zero = Self(bytes: 0, fileCount: 0)

    public let bytes: Int

    public let fileCount: Int

    public init(bytes: Int, fileCount: Int) {
        self.bytes = bytes
        self.fileCount = fileCount
    }

    public func formatted() -> String {
        "\(formattedBytes()) / \(fileCount) \(fileCount == 1 ? "file" : "files")"
    }

    public func formattedBytes() -> String {
        // en_US_POSIX so the separator and units cannot change with the reader's device: the file
        // is read by whoever the user sends it to.
        Int64(bytes).formatted(
            .byteCount(style: .file)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}

@DependencyClient
public struct StorageUsageClient: Sendable {

    // Takes URLs rather than a directory so one call can answer for a cache directory and a
    // handful of loose files. Each URL may be either.
    public var measure: @Sendable (_ urls: [URL]) -> StorageUsage = { _ in .zero }
}

extension StorageUsageClient: DependencyKey {

    public static let liveValue = Self(
        measure: { urls in
            var bytes = 0
            var fileCount = 0

            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory) else {
                    continue
                }

                guard isDirectory.boolValue else {
                    bytes += size(of: url)
                    fileCount += 1
                    continue
                }

                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
                )
                while let child = enumerator?.nextObject() as? URL {
                    guard (try? child.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                        continue
                    }
                    bytes += size(of: child)
                    fileCount += 1
                }
            }

            return StorageUsage(bytes: bytes, fileCount: fileCount)
        }
    )

    private static func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}

extension StorageUsageClient: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(measure: { _ in .zero })
}

public extension DependencyValues {

    var storageUsage: StorageUsageClient {
        get { self[StorageUsageClient.self] }
        set { self[StorageUsageClient.self] = newValue }
    }
}
