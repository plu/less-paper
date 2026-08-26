@testable import MarketingKit

import SwiftUI
import Testing
import TestSupport
import UIKit

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct MarketingScreenshotTests {

    // A flat stand-in rather than a real capture: the layout is what is under test, and using a
    // screenshot here would move every reference whenever the app's UI moved.
    //
    // It carries the device's own aspect ratio, because that is what decides how the capture sits
    // in the frame - a stand-in shaped like a phone would make the iPad references a fiction.
    private static func capture(for device: MarketingDevice) -> Image {
        // A tenth of the device's pixel size at scale 1, so the stand-in's proportions are the
        // device's exactly and no point-versus-pixel conversion sits in between. A flat grey rather than a
        // system colour, which would move under an OS change and take every reference with it.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let size = CGSize(width: device.size.width / 10, height: device.size.height / 10)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(gray: 0.75, alpha: 1)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
        return Image(uiImage: image)
    }

    @Test(arguments: MarketingScreen.allCases)
    func testSnapshot_iPhone(screen: MarketingScreen) async throws {
        assertSnapshot(
            of: MarketingScreenshot(capture: Self.capture(for: .iPhone), screen: screen, device: .iPhone),
            as: .image(layout: .fixed(width: 660, height: 1434)),
            named: screen.fileStem
        )
    }

    @Test(arguments: MarketingScreen.allCases)
    func testSnapshot_iPad(screen: MarketingScreen) async throws {
        assertSnapshot(
            of: MarketingScreenshot(capture: Self.capture(for: .iPad), screen: screen, device: .iPad),
            as: .image(layout: .fixed(width: 1024, height: 1366)),
            named: screen.fileStem
        )
    }
}
