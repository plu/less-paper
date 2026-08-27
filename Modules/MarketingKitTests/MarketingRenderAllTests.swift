@testable import MarketingKit

import ApiInterface
import Foundation
import SwiftUI
import Testing
import UIKit

// Renders every committed capture into a finished App Store image.
//
// A test that writes artefacts, which is the shape SNAPSHOT_RECORD already uses in this repository.
// It is skipped unless asked for, so an ordinary test run does not spend seconds writing 28 PNGs
// nobody asked it to.
//
// Asked for with a file rather than an environment variable: a TEST_RUNNER_-prefixed variable does
// not reach the test process here, which is the same reason re-recording a snapshot means toggling
// SNAPSHOT_RECORD in the scheme by hand. mise/tasks/screenshots/frame writes the marker and removes
// it again.
@MainActor
@Suite
struct MarketingRenderAllTests {

    // nonisolated because .enabled(if:) evaluates its closure outside the main actor.
    private nonisolated static var isRequested: Bool {
        FileManager.default.fileExists(
            atPath: URL.projectRoot.appending(path: ".marketing-render").path()
        )
    }

    @Test(.enabled(if: MarketingRenderAllTests.isRequested))
    func test_renderEveryScreenshot() async throws {
        let root = URL.projectRoot
        var written = 0

        for locale in ["en-US", "de-DE"] {
            for device in MarketingDevice.allCases {
                for screen in MarketingScreen.allCases {
                    let name = "\(device.capturePrefix)-\(screen.fileStem)"
                    let captureURL = root.appending(path: "Screenshots/Captures/\(locale)/\(name).png")

                    let capture = try #require(
                        UIImage(data: try Data(contentsOf: captureURL)),
                        "Missing capture \(locale)/\(name).png - run `mise run screenshots:record`"
                    )

                    let data = try #require(
                        MarketingScreenshot.render(
                            capture: Image(uiImage: capture),
                            screen: screen,
                            device: device,
                            locale: Locale(identifier: locale)
                        )
                    )

                    let directory = root.appending(path: "fastlane/screenshots/\(locale)")
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try data.write(to: directory.appending(path: "\(name)_framed.png"))
                    written += 1
                }
            }
        }

        #expect(written == 28)
    }
}
