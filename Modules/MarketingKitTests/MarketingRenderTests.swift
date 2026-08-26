@testable import MarketingKit

import SwiftUI
import Testing
import UIKit

@MainActor
@Suite
struct MarketingRenderTests {

    // The size is the whole point. frameit's silent failure was producing a plausible image of the
    // wrong dimensions, which App Store Connect refuses on upload - so the size is asserted rather
    // than assumed.
    @Test(arguments: MarketingDevice.allCases)
    func test_render_isExactlyTheRequiredSize(device: MarketingDevice) async throws {
        let data = try #require(
            MarketingScreenshot.render(capture: Self.capture, screen: .inbox, device: device)
        )
        let rendered = try #require(UIImage(data: data))

        #expect(rendered.size.width == device.size.width)
        #expect(rendered.size.height == device.size.height)
    }

    private static var capture: Image {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let size = CGSize(width: 100, height: 200)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(gray: 0.75, alpha: 1)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return Image(uiImage: image)
    }
}
