import Nuke
import UIKit

struct TestImageLoader: Nuke.DataLoading {

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> Cancellable {
        switch result {
        case let .failure(error):
            completion(error)
        case let .success(image):
            didReceiveData(
                image.pngData() ?? Data(),
                URLResponse()
            )
            completion(nil)
        case .none:
            break
        }
        return AnyCancellable {}
    }

    init(result: Result<UIImage, Error>? = .success(UIImage(resource: .testPattern))) {
        self.result = result
    }

    private let result: Result<UIImage, Error>?
}
