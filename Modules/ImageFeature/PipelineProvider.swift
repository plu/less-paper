import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Nuke
import UIKit

@DependencyClient
struct PipelineProvider: Sendable {

    var build: @Sendable (
        _ server: Server
    ) -> ImagePipeline = { _ in .shared }
}

extension PipelineProvider: DependencyKey {
    static let liveValue = Self(build: { server in
        ImagePipeline {
            $0.dataLoader = ImageLoader(server: server)
            $0.dataCache = try? DataCache(name: "default")
            $0.imageCache = Nuke.ImageCache.shared
        }
    })
}

extension PipelineProvider: TestDependencyKey {

    static let failingValue = Self(build: { _ in
        ImagePipeline {
            $0.dataLoader = TestImageLoader(result: .failure(URLError(.networkConnectionLost)))
            $0.imageCache = TestImageCache(image: nil)
        }
    })

    static let loadingValue = Self(build: { _ in
        ImagePipeline {
            $0.dataLoader = TestImageLoader(result: nil)
            $0.imageCache = TestImageCache(image: nil)
        }
    })

    static let previewValue = Self(build: { _ in
        ImagePipeline {
            $0.dataLoader = TestImageLoader()
            $0.dataCache = try? DataCache(name: "default")
            $0.imageCache = TestImageCache()
        }
    })

    static let testValue = Self(build: { _ in
        ImagePipeline {
            $0.dataLoader = TestImageLoader()
            $0.dataCache = try? DataCache(name: "default")
            $0.imageCache = TestImageCache()
        }
    })
}

extension DependencyValues {
    var imagePipeline: PipelineProvider {
        get { self[PipelineProvider.self] }
        set { self[PipelineProvider.self] = newValue }
    }
}
