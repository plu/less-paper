@testable import MarketingKit

import ApiInterface
import Foundation
import SwiftUI
import Testing
import TestSupport
import UIKit

// Renders every committed capture into a finished App Store image.
//
// A test that writes artefacts, which is the shape SNAPSHOT_RECORD already uses in this repository.
// It is skipped unless asked for, so an ordinary test run does not spend seconds writing a PNG per
// screen, device and language that nobody asked it to.
//
// Asked for with a file rather than an environment variable. That was chosen on the belief that a
// TEST_RUNNER_-prefixed variable does not reach the test process, which is wrong - it does, as
// `mise run snapshots:record` relies on - so this could be a variable like SNAPSHOT_RECORD is. The
// marker works and mise/tasks/screenshots/frame writes and removes it; changing it would mean
// changing that task too, so it stays until there is a reason beyond tidiness.
@MainActor
@Suite(
    .testDependencies()
)
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
