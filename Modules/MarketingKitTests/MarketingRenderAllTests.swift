@testable import MarketingKit

import ApiInterface
import Foundation
import SwiftUI
import Testing
import UIKit

// Renders every committed capture into a finished App Store image.
//
// A test that writes artefacts, which is the shape SNAPSHOT_RECORD already uses in this repository.
// It is skipped unless asked for, so an ordinary test run does not spend seconds writing a PNG per
// screen, device and language that nobody asked it to.
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
        let locales = ["en-US", "de-DE"]
        var written = 0

        for locale in locales {
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

        // Derived rather than a literal. What this asserts is that every combination was written,
        // not that there happen to be so many of them — as a hardcoded number it simply broke on
        // the day a screen was added, which says nothing about whether the render worked.
        #expect(written == locales.count * MarketingDevice.allCases.count * MarketingScreen.allCases.count)
    }
}
