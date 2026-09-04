import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Nuke

// Exists so AppFeature can report the thumbnail cache without importing Nuke, and so the number is
// stubbable. It reads the same store PipelineProvider builds - DataCache(name: "default").
@DependencyClient
public struct ImageCacheUsage: Sendable {

    public var read: @Sendable () async -> StorageUsage = { .zero }
}

extension ImageCacheUsage: DependencyKey {

    public static let liveValue = Self(
        read: {
            guard let cache = try? DataCache(name: "default") else {
                return .zero
            }

            // Both properties enumerate the directory, so this hops off whatever actor called it.
            return await Task.detached(priority: .utility) {
                StorageUsage(bytes: cache.totalSize, fileCount: cache.totalCount)
            }.value
        }
    )
}

extension ImageCacheUsage: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(read: { .zero })
}

public extension DependencyValues {

    var imageCacheUsage: ImageCacheUsage {
        get { self[ImageCacheUsage.self] }
        set { self[ImageCacheUsage.self] = newValue }
    }
}
