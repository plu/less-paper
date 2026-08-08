import Nuke
import UIKit

final class TestImageCache: Nuke.ImageCaching {

    subscript(key: Nuke.ImageCacheKey) -> Nuke.ImageContainer? {
        get {
            guard let image else {
                return nil
            }

            return .init(image: image)
        }
        // swiftlint:disable:next unused_setter_value
        set {}
    }

    func removeAll() {}

    init(image: UIImage? = UIImage(resource: .testPattern)) {
        self.image = image
    }

    private let image: UIImage?
}
