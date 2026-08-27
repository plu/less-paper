import Dependencies
import Foundation
import Nuke

public extension DependencyValues {

    // Serves every thumbnail from the supplied closure instead of a server. Screenshot mode uses
    // this; the closure keeps Nuke on this side of the boundary, so a caller only has to answer
    // "what are the bytes for this URL".
    mutating func useStubbedImagePipeline(
        data: @escaping @Sendable (URL) -> Data?
    ) {
        imagePipeline = PipelineProvider(build: { _ in
            ImagePipeline {
                $0.dataLoader = StubbedImageLoader(data: data)
                $0.imageCache = Nuke.ImageCache()
            }
        })
    }
}

private struct StubbedImageLoader: Nuke.DataLoading {

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> Nuke.Cancellable {
        guard let url = request.url,
              let data = data(url)
        else {
            completion(URLError(.fileDoesNotExist))
            return AnyCancellable {}
        }

        didReceiveData(data, URLResponse())
        completion(nil)
        return AnyCancellable {}
    }

    let data: @Sendable (URL) -> Data?
}
