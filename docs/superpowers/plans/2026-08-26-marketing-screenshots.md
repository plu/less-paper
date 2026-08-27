# Marketing Screenshots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace frameit with a SwiftUI renderer this repository owns, and split the screenshot pipeline into record, frame and upload so that changing a caption costs seconds rather than an hour.

**Architecture:** A new `MarketingKit` framework holds one SwiftUI view that turns a capture plus a caption into a finished App Store image at an exact size. Its tests do two jobs: snapshot-test every caption at both device sizes in both languages, and — behind an environment variable, exactly as `SNAPSHOT_RECORD` already works — render the committed captures into finished images. The captures move from being transient output into committed inputs under Git LFS.

**Tech Stack:** Swift 6, SwiftUI, `ImageRenderer`, swift-snapshot-testing, Tuist 4.205.0, Swift Testing (unit), XCTest/XCUITest (capture), fastlane (record looping and `deliver` only), Git LFS.

**Spec:** [2026-08-26-marketing-screenshots-design.md](../specs/2026-08-26-marketing-screenshots-design.md)

## Global Constraints

- **Comments:** Only `//`. Never `///`, never `/** */`. Comment only when a future reader would otherwise stop and wonder why. (`AGENTS.md`)
- **`@ViewAction` views send with `send`, never `store.send`.** Not relevant to `MarketingKit`, which has no store, but it applies if any app view is touched. (`AGENTS.md`)
- **Never run Docker.** Screenshot work needs no paperless instance at all — snapshot mode reads `Screenshots/Fixtures`. (`AGENTS.md`)
- **Every `tuist test` needs `--no-selective-testing`**, or an unchanged target reports success having run nothing.
- **Regenerate after any `Tuist/ProjectDescriptionHelpers/` change:** `mise exec -- tuist install && mise exec -- tuist generate --no-open`.
- **The two required output sizes are exactly `1320x2868` (6.9" iPhone) and `2048x2732` (13" iPad).** Anything else is refused by App Store Connect.
- **Captions are fixed by the spec.** Copy them verbatim from the Captions table; do not reword.
- **German is Du, never Sie.** The app already speaks Du in every string that addresses the user.
- **Device and language matrix:** `iPhone 17 Pro Max` and `iPad Pro 13-inch (M5)`; `en-US` and `de-DE`.
- **Screens, in order:** `01-Inbox`, `02-Documents`, `03-Search`, `04-Tags`, `05-View`, `06-Edit`, `07-Settings`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/MarketingKit/MarketingScreenshot.swift` | The SwiftUI layout: capture + caption + size → the finished image's view. |
| `Modules/MarketingKit/MarketingScreen.swift` | The seven screens as a type, each knowing its file stem and its caption key. |
| `Modules/MarketingKit/MarketingDevice.swift` | The two devices as a type, each knowing its output size and its capture file prefix. |
| `Modules/MarketingKit/Resources/Marketing.xcstrings` | The captions, per language. |
| `Modules/MarketingKitTests/MarketingScreenshotTests.swift` | Snapshot tests: every caption, both devices, both languages. |
| `Modules/MarketingKitTests/MarketingRenderTests.swift` | The render entry point, gated by `MARKETING_RENDER`. |
| `mise/tasks/screenshots/frame` | Renders committed captures into finished images. |
| `mise/tasks/ci/screenshots/frame` | The CI entry point for the same. |
| `.github/workflows/screenshots-record.yml` | Capture, then open a PR with the new captures. |
| `.github/workflows/screenshots-frame.yml` | Render, contact sheet in the summary, artifact. |
| `.github/workflows/screenshots-upload.yml` | Render, then deliver. |
| `Screenshots/contact_sheet.py` | Tiles images into one downscaled sheet for the step summary. |

**Modified:**

| File | Change |
|---|---|
| `Tuist/ProjectDescriptionHelpers/Module.swift` | Add `marketingKit` and `marketingKitTests`. |
| `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` | Their dependency blocks. |
| `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift` | Add both to the empty-scheme branch. |
| `Modules/AppSnapshots/SnapshotTests.swift` | Write captures to `Screenshots/Captures/`. |
| `fastlane/Fastfile` | Drop the `frame` lane and its helpers; keep `screenshots` and `upload_screenshots`. |
| `fastlane/Snapfile` | Output into `Screenshots/Captures`. |
| `.gitignore` | Stop ignoring captures; keep ignoring rendered output. |
| `AGENTS.md` | Replace the frameit section with how the three stages work. |

**Deleted:** `fastlane/screenshots/Framefile.json`, `fastlane/screenshots/en-US/keyword.strings`, `fastlane/screenshots/de-DE/keyword.strings`, `fastlane/screenshots/en-US/title.strings`, `fastlane/screenshots/de-DE/title.strings`.

---

## Task 1: `MarketingKit` with the layout and its tests

The layout first, proven by snapshot tests, before anything in the pipeline moves. Nothing in this task touches capture, fastlane or CI — if it goes wrong, nothing else is affected.

**Files:**
- Create: `Modules/MarketingKit/MarketingDevice.swift`, `Modules/MarketingKit/MarketingScreen.swift`, `Modules/MarketingKit/MarketingScreenshot.swift`, `Modules/MarketingKit/Resources/Marketing.xcstrings`
- Create: `Modules/MarketingKitTests/MarketingScreenshotTests.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`

**Interfaces:**
- Consumes: `Color.m3Primary` and `Color.m3OnSurface` from `Components`; `assertSnapshot(of:as:named:)` from `TestSupport`.
- Produces:
  - `MarketingDevice` with `.iPhone`, `.iPad`; `var size: CGSize`; `var capturePrefix: String`
  - `MarketingScreen` with the seven cases; `var fileStem: String`; `var caption: LocalizedStringResource`
  - `MarketingScreenshot(capture:screen:device:)` — a `View`
  - `MarketingScreenshot.render(capture:screen:device:) -> Data?` — PNG bytes at the device's exact size

- [x] **Step 1: Add the two modules to Tuist**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add to the enum, keeping alphabetical order:

```swift
    case marketingKit = "MarketingKit"
    case marketingKitTests = "MarketingKitTests"
```

Add `.marketingKit` to the framework list in the `product` switch (the branch ending `Environment.staticFrameworks.getBoolean(default: false) ? .staticFramework : .framework`), and `.marketingKitTests` to the `.unitTests` branch.

Add `.marketingKit` to the `true` branch of `codeCoverageTarget`, and `.marketingKitTests` to the `false` branch.

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`:

```swift
        case .marketingKit:
            [
                .target(.components),
            ]
        case .marketingKitTests:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.marketingKit),
                .target(.testSupport),
            ]
```

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, add `.marketingKit,` and `.marketingKitTests,` to the trailing branch that returns `[]`.

- [x] **Step 2: Write the device and screen types**

Create `Modules/MarketingKit/MarketingDevice.swift`:

```swift
import Foundation

// The two sets Apple requires: a 6.9" iPhone, and a 13" iPad for an app that runs on iPad.
// Everything smaller is scaled from these by App Store Connect.
public enum MarketingDevice: String, CaseIterable, Sendable {
    case iPhone
    case iPad

    // Exact, because App Store Connect refuses anything else.
    public var size: CGSize {
        switch self {
        case .iPhone:
            CGSize(width: 1320, height: 2868)
        case .iPad:
            CGSize(width: 2048, height: 2732)
        }
    }

    // How the capture files are named, which is the simulator the capture ran on.
    public var capturePrefix: String {
        switch self {
        case .iPhone:
            "iPhone 17 Pro Max"
        case .iPad:
            "iPad Pro 13-inch (M5)"
        }
    }
}
```

Create `Modules/MarketingKit/MarketingScreen.swift`:

```swift
import Foundation

public enum MarketingScreen: String, CaseIterable, Sendable {
    case inbox
    case documents
    case search
    case tags
    case view
    case edit
    case settings

    // Matches the names the capture writes, so the numbering that orders them on the store survives
    // the trip through the renderer.
    public var fileStem: String {
        switch self {
        case .inbox:
            "01-Inbox"
        case .documents:
            "02-Documents"
        case .search:
            "03-Search"
        case .tags:
            "04-Tags"
        case .view:
            "05-View"
        case .edit:
            "06-Edit"
        case .settings:
            "07-Settings"
        }
    }

    public var caption: LocalizedStringResource {
        switch self {
        case .inbox:
            .init("marketing.inbox", bundle: .atURL(Bundle.module.bundleURL))
        case .documents:
            .init("marketing.documents", bundle: .atURL(Bundle.module.bundleURL))
        case .search:
            .init("marketing.search", bundle: .atURL(Bundle.module.bundleURL))
        case .tags:
            .init("marketing.tags", bundle: .atURL(Bundle.module.bundleURL))
        case .view:
            .init("marketing.view", bundle: .atURL(Bundle.module.bundleURL))
        case .edit:
            .init("marketing.edit", bundle: .atURL(Bundle.module.bundleURL))
        case .settings:
            .init("marketing.settings", bundle: .atURL(Bundle.module.bundleURL))
        }
    }
}
```

- [x] **Step 3: Write the caption catalog**

Create `Modules/MarketingKit/Resources/Marketing.xcstrings` with these exact strings. The format matches `Shared/Framework/Resources/Localizable.xcstrings`; copy its shape, with `"sourceLanguage" : "en"` and each key carrying `en` and `de` localizations.

| Key | en | de |
|---|---|---|
| `marketing.inbox` | Your inbox, everything just arrived | Dein Eingang, alles Neue auf einen Blick |
| `marketing.documents` | Your whole archive, in your pocket | Dein ganzes Archiv in der Tasche |
| `marketing.search` | Find any document in seconds | Finde jedes Dokument in Sekunden |
| `marketing.tags` | Narrow it down by tag, type or date | Grenze nach Tag, Typ oder Datum ein |
| `marketing.view` | Read the whole document, right here | Lies das ganze Dokument, direkt hier |
| `marketing.edit` | Fix a title or tag on the spot | Korrigiere Titel und Tags direkt |
| `marketing.settings` | Your setup, under control | Deine Einstellungen, alles im Griff |

- [x] **Step 4: Write the failing snapshot test**

Create `Modules/MarketingKitTests/MarketingScreenshotTests.swift`:

```swift
@testable import MarketingKit

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct MarketingScreenshotTests {

    // A solid stand-in for the capture. The layout is what is under test; using a real screenshot
    // here would make the reference change whenever the app's UI did.
    private var capture: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 217)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 217))
        }
    }

    @Test(arguments: MarketingScreen.allCases)
    func testSnapshot_iPhone(screen: MarketingScreen) async throws {
        assertSnapshot(
            of: MarketingScreenshot(capture: Image(uiImage: capture), screen: screen, device: .iPhone),
            as: .image(layout: .fixed(width: 660, height: 1434)),
            named: screen.fileStem
        )
    }

    @Test(arguments: MarketingScreen.allCases)
    func testSnapshot_iPad(screen: MarketingScreen) async throws {
        assertSnapshot(
            of: MarketingScreenshot(capture: Image(uiImage: capture), screen: screen, device: .iPad),
            as: .image(layout: .fixed(width: 1024, height: 1366)),
            named: screen.fileStem
        )
    }
}
```

- [x] **Step 5: Run it to verify it fails**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL to build, `cannot find 'MarketingScreenshot' in scope`.

- [x] **Step 6: Write the layout**

Create `Modules/MarketingKit/MarketingScreenshot.swift`:

```swift
import Components
import SwiftUI

// One App Store screenshot: the captured screen on the app's own dark ground, under a caption.
//
// No device bezel. Dropping it returns about a fifth of the canvas height, which is what the
// document rows need to stay legible at the size the App Store actually shows a screenshot.
public struct MarketingScreenshot: View {

    public var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.height / 100

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0, green: 0.31, blue: 0.30), Color(red: 0, green: 0.19, blue: 0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: unit * 3) {
                    Text(screen.caption)
                        .font(.system(size: unit * 4.2, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        // The caption may not shrink below this: past it the type is too small to
                        // read at thumbnail size, and a caption that will not fit is a copy
                        // problem the snapshot test should surface rather than hide.
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, unit * 6)
                        .padding(.top, unit * 6)

                    capture
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: unit * 2.2))
                        .shadow(color: .black.opacity(0.35), radius: unit * 1.2, y: unit * 0.6)
                        .padding(.horizontal, unit * 8)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    public init(
        capture: Image,
        screen: MarketingScreen,
        device: MarketingDevice
    ) {
        self.capture = capture
        self.screen = screen
        self.device = device
    }

    private let capture: Image
    private let device: MarketingDevice
    private let screen: MarketingScreen
}
```

- [x] **Step 7: Record the references and confirm they pass**

Recording writes the references; it always reports a failure while doing so, which is expected.

```bash
mise exec -- tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing -- TEST_RUNNER_SNAPSHOT_RECORD=all
```

Then run again without recording:

```bash
mise exec -- tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS, 14 tests. Look at the recorded references in `Snapshots/MarketingKitTests/` before continuing — they are the design, and this is the moment to catch a caption that wraps badly.

- [x] **Step 8: Commit**

```bash
git add Modules/MarketingKit Modules/MarketingKitTests Snapshots/MarketingKitTests Tuist
git commit -m "feat: add the marketing screenshot layout"
```

---

## Task 2: Render at the exact output size

The layout exists; this turns it into PNG bytes of exactly the size App Store Connect accepts. A test proves the size, because the size is the thing frameit silently got wrong.

**Files:**
- Modify: `Modules/MarketingKit/MarketingScreenshot.swift`
- Create: `Modules/MarketingKitTests/MarketingRenderTests.swift`

**Interfaces:**
- Consumes: `MarketingScreenshot(capture:screen:device:)`, `MarketingDevice.size` (Task 1).
- Produces: `MarketingScreenshot.render(capture:screen:device:) -> Data?`

- [x] **Step 1: Write the failing test**

Create `Modules/MarketingKitTests/MarketingRenderTests.swift`:

```swift
@testable import MarketingKit

import SwiftUI
import Testing
import UIKit

@MainActor
@Suite
struct MarketingRenderTests {

    // The size is the whole point: frameit's silent failure was producing a plausible image of the
    // wrong dimensions, which App Store Connect refuses on upload.
    @Test(arguments: MarketingDevice.allCases)
    func test_render_isExactlyTheRequiredSize(device: MarketingDevice) async throws {
        let capture = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 217)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 217))
        }

        let data = try #require(
            MarketingScreenshot.render(capture: Image(uiImage: capture), screen: .inbox, device: device)
        )
        let rendered = try #require(UIImage(data: data))

        #expect(rendered.size.width == device.size.width)
        #expect(rendered.size.height == device.size.height)
    }
}
```

- [x] **Step 2: Run it to verify it fails**

```bash
mise exec -- tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL to build, `type 'MarketingScreenshot' has no member 'render'`.

- [x] **Step 3: Add the renderer**

Append to `Modules/MarketingKit/MarketingScreenshot.swift`:

```swift
public extension MarketingScreenshot {

    // scale is 1 because size is already in pixels: these are the exact dimensions App Store
    // Connect accepts, not points to be multiplied by a device factor.
    @MainActor
    static func render(
        capture: Image,
        screen: MarketingScreen,
        device: MarketingDevice
    ) -> Data? {
        let renderer = ImageRenderer(
            content: Self(capture: capture, screen: screen, device: device)
                .frame(width: device.size.width, height: device.size.height)
        )
        renderer.scale = 1
        renderer.isOpaque = true

        return renderer.uiImage?.pngData()
    }
}
```

- [x] **Step 4: Run it to verify it passes**

```bash
mise exec -- tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS, 16 tests.

- [x] **Step 5: Commit**

```bash
git add Modules/MarketingKit Modules/MarketingKitTests
git commit -m "feat: render a marketing screenshot at the required size"
```

---

## Task 3: Move captures into the repository

The capture stage stops feeding fastlane and starts writing a committed input. This is what makes framing cheap, so it comes before the renderer is wired to real files.

**Files:**
- Modify: `Modules/AppSnapshots/SnapshotTests.swift`, `fastlane/Snapfile`, `.gitignore`, `.gitattributes` (verify only)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Screenshots/Captures/<locale>/<device capturePrefix>-<screen fileStem>.png`

- [x] **Step 1: Point the Snapfile at the new directory**

In `fastlane/Snapfile`, change the output directory:

```ruby
output_directory("./Screenshots/Captures")
```

- [x] **Step 2: Stop ignoring captures, keep ignoring rendered output**

In `.gitignore`, replace the two fastlane screenshot lines with:

```
# Rendered marketing images are regenerated by `mise run screenshots:frame` in seconds. The
# captures they are rendered from are committed instead - they cost an hour of simulator time.
fastlane/screenshots/
```

Confirm `.gitattributes` already routes `*.png` through LFS — it does, and the captures rely on it.

- [x] **Step 3: Capture into the new location**

```bash
mise run screenshots:fixtures -- --url http://192.168.64.1:8000   # only if the fixtures are stale
mise exec -- bundle exec fastlane screenshots
```

Expected: 28 files under `Screenshots/Captures/en-US/` and `Screenshots/Captures/de-DE/`, 14 each.

- [x] **Step 4: Verify the sizes before committing 20 MB**

```bash
magick identify Screenshots/Captures/*/*.png | grep -oE " [0-9]+x[0-9]+ " | sort | uniq -c
```

Expected: 14 at `1320x2868`, 14 at `2048x2732`.

- [x] **Step 5: Commit**

```bash
git add .gitignore fastlane/Snapfile Screenshots/Captures
git commit -m "feat: commit the screenshot captures"
```

---

## Task 4: Render the committed captures

**Files:**
- Modify: `Modules/MarketingKitTests/MarketingRenderTests.swift`
- Create: `mise/tasks/screenshots/frame`

**Interfaces:**
- Consumes: `MarketingScreenshot.render(capture:screen:device:)` (Task 2); the captures (Task 3).
- Produces: `fastlane/screenshots/<locale>/<device capturePrefix>-<screen fileStem>_framed.png`

- [x] **Step 1: Write the render entry point**

Append to `Modules/MarketingKitTests/MarketingRenderTests.swift`:

```swift
@MainActor
@Suite
struct MarketingRenderAllTests {

    // A test that writes artefacts, gated the way SNAPSHOT_RECORD already gates the snapshot
    // references. Without the variable it is skipped, so an ordinary test run does not write files.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MARKETING_RENDER"] == "true"))
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
                            device: device
                        )
                    )

                    let outputDirectory = root.appending(path: "fastlane/screenshots/\(locale)")
                    try FileManager.default.createDirectory(
                        at: outputDirectory,
                        withIntermediateDirectories: true
                    )
                    try data.write(to: outputDirectory.appending(path: "\(name)_framed.png"))
                    written += 1
                }
            }
        }

        #expect(written == 28)
    }
}
```

Add `import ApiInterface` at the top of the file for `URL.projectRoot`, and add `.target(.apiInterface)` to `marketingKitTests` in `Module+Dependencies.swift`.

- [x] **Step 2: Write the mise task**

Create `mise/tasks/screenshots/frame`:

```bash
#!/usr/bin/env bash
#MISE description="Render the committed captures into finished App Store images"
set -euo pipefail

# Reads Screenshots/Captures and writes fastlane/screenshots. No simulator app, no container: this
# is a pure image transform, which is why it takes seconds where capturing takes an hour.
tuist test MarketingKit -d "iPhone 17 Pro" --no-selective-testing -- TEST_RUNNER_MARKETING_RENDER=true
```

Make it executable: `chmod +x mise/tasks/screenshots/frame`.

- [x] **Step 3: Run it**

```bash
mise run screenshots:frame
magick identify fastlane/screenshots/*/*_framed.png | grep -oE " [0-9]+x[0-9]+ " | sort | uniq -c
```

Expected: 14 at `1320x2868`, 14 at `2048x2732`. Look at several before continuing.

- [x] **Step 4: Commit**

```bash
git add Modules/MarketingKitTests mise/tasks/screenshots/frame Tuist
git commit -m "feat: render the committed captures"
```

---

## Task 5: Delete frameit

Only once its replacement is producing correct images.

**Files:**
- Modify: `fastlane/Fastfile`, `mise/tasks/ci/screenshots/capture`
- Delete: `fastlane/screenshots/Framefile.json`, the four `.strings` files

- [x] **Step 1: Delete the frameit configuration**

```bash
git rm fastlane/screenshots/Framefile.json \
  fastlane/screenshots/en-US/keyword.strings fastlane/screenshots/en-US/title.strings \
  fastlane/screenshots/de-DE/keyword.strings fastlane/screenshots/de-DE/title.strings
```

- [x] **Step 2: Strip the frame lane and its helpers from the Fastfile**

Remove the `frame` and `screenshots_framed` lanes, the `FRAMES` and `BACKGROUND` constants, and the `link_fonts`, `rename_to_framed_devices` and `write_background` methods. Keep `screenshots`, `upload_screenshots`, `clear_captures` and `SCREENSHOTS`.

Point `SCREENSHOTS` at the captures directory, since that is now what `snapshot` writes:

```ruby
SCREENSHOTS = File.expand_path("../Screenshots/Captures", __dir__)
```

and change `upload_screenshots` to deliver the rendered images instead:

```ruby
      screenshots_path: File.expand_path("screenshots", __dir__),
```

- [x] **Step 3: Update the CI capture task**

In `mise/tasks/ci/screenshots/capture`, replace `bundle exec fastlane screenshots_framed` with `bundle exec fastlane screenshots`.

- [x] **Step 4: Verify nothing references frameit**

```bash
grep -rn "frameit\|Framefile\|keyword.strings" --exclude-dir=.git --exclude-dir=vendor . | grep -v docs/superpowers
```

Expected: no output.

- [x] **Step 5: Commit**

```bash
git add -A fastlane mise
git commit -m "refactor: delete frameit"
```

---

## Task 6: The contact sheet

Every workflow shows its images in the step summary. The sheet is one image so the summary stays small.

**Files:**
- Create: `Screenshots/contact_sheet.py`

**Interfaces:**
- Produces: a single PNG tiling the given images, plus a Markdown table on stdout.

- [x] **Step 1: Write the script**

Create `Screenshots/contact_sheet.py`:

```python
#!/usr/bin/env python3
"""Tile screenshots into one downscaled sheet, and print a Markdown table for the step summary.

    python3 Screenshots/contact_sheet.py --input Screenshots/Captures --output sheet.png
"""

import argparse
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--width", type=int, default=180)
    args = parser.parse_args()

    images = sorted(Path(args.input).glob("*/*.png"))
    if not images:
        raise SystemExit(f"error: no images under {args.input}")

    subprocess.run(
        ["magick", "montage", *[str(i) for i in images],
         "-tile", "7x", "-geometry", f"{args.width}x+6+6",
         "-background", "white", "-label", "%f",
         "-pointsize", "11", args.output],
        check=True,
    )

    print(f"| Locale | Device | Screens |")
    print(f"|---|---|---|")
    groups = {}
    for image in images:
        locale = image.parent.name
        device = image.stem.rsplit("-", 1)[0]
        groups.setdefault((locale, device), []).append(image)
    for (locale, device), files in sorted(groups.items()):
        print(f"| {locale} | {device} | {len(files)} |")


if __name__ == "__main__":
    sys.exit(main())
```

- [x] **Step 2: Run it**

```bash
python3 Screenshots/contact_sheet.py --input fastlane/screenshots --output /tmp/sheet.png
magick identify /tmp/sheet.png
```

Expected: a table on stdout, and a single PNG under about 2 MB.

- [x] **Step 3: Commit**

```bash
git add Screenshots/contact_sheet.py
git commit -m "feat: add a contact sheet for the step summary"
```

---

## Task 7: The three workflows

**Files:**
- Create: `.github/workflows/screenshots-record.yml`, `screenshots-frame.yml`, `screenshots-upload.yml`
- Create: `mise/tasks/ci/screenshots/frame`
- Delete: `.github/workflows/screenshots.yml`

- [x] **Step 1: Settle whether images render in a step summary**

This decides the shape of all three summaries, so it goes first and cheaply. Add a temporary step to `screenshots-frame.yml` that writes a small `data:` URI image into `$GITHUB_STEP_SUMMARY`, dispatch it, and look at the result.

```bash
printf '### data URI probe\n<img src="data:image/png;base64,%s" width="120">\n' \
  "$(magick -size 120x60 xc:teal png:- | base64)" >> "$GITHUB_STEP_SUMMARY"
```

If the image renders, embed the contact sheet the same way. If it is stripped — which is the likelier outcome, as GitHub sanitises summary Markdown — fall back to the artifact link plus the table, and for **Record** use raw URLs against the branch it just pushed, which do render. Record the answer in a comment in the workflow so nobody probes it twice.

- [x] **Step 2: Write the CI frame task**

Create `mise/tasks/ci/screenshots/frame`:

```bash
#!/usr/bin/env bash
#MISE description="Render the committed captures, for CI"
set -euo pipefail

bundle config set --local path vendor/bundle
bundle check >/dev/null 2>&1 || bundle install

tuist install
tuist generate --no-open

mise run screenshots:frame
```

- [x] **Step 3: Write the Record workflow**

Create `.github/workflows/screenshots-record.yml`. Manual only. After `mise ci:screenshots:capture`, commit the captures to a branch named `screenshots/record-${{ github.run_id }}` and open a pull request with `gh pr create`. Needs `permissions: contents: write` and `pull-requests: write`. Write the contact sheet into the summary using whatever Step 1 established.

- [x] **Step 4: Write the Frame workflow**

Create `.github/workflows/screenshots-frame.yml`. Triggers: `workflow_dispatch`, and `pull_request` filtered by `paths: [Modules/MarketingKit/**, Modules/MarketingKitTests/**, Screenshots/Captures/**]`. Runs `mise ci:screenshots:frame`, uploads the rendered images as an artifact, and writes the contact sheet into the summary.

- [x] **Step 5: Write the Upload workflow**

Create `.github/workflows/screenshots-upload.yml`. Manual only, with an `upload` input defaulting to false. Runs `mise ci:screenshots:frame` then `mise ci:screenshots:upload`, and writes the contact sheet of what it sent.

- [x] **Step 6: Delete the old workflow**

```bash
git rm .github/workflows/screenshots.yml
```

- [x] **Step 7: Dispatch Frame and check the summary**

Expected: 28 rendered images in the artifact, and a summary showing them.

- [x] **Step 8: Commit**

```bash
git add -A .github mise
git commit -m "feat: split the screenshot workflows into record, frame and upload"
```

---

## Task 8: Documentation

**Files:**
- Modify: `AGENTS.md`

- [x] **Step 1: Replace the frameit section**

Replace the three frameit traps under "App Store screenshots run on fixtures, never a server" with how the three stages work: captures are committed inputs produced by Record, framing is a unit test that runs in seconds, and uploading is manual. Keep the paragraph about fixtures and `SNAPSHOT_MODE`, which is unchanged, and the note that neither ships in a release build.

- [x] **Step 2: Record the execution notes**

Add an "Execution notes" section to this plan in the shape the UI testing plans use: what the render actually costs, anything in this plan that turned out wrong, and the answer to the `data:` URI question from Task 7 Step 1.

- [x] **Step 3: Commit**

```bash
git add AGENTS.md docs/superpowers/plans/2026-08-26-marketing-screenshots.md
git commit -m "docs: record how the screenshot stages work"
```

---

## Self-Review

**Spec coverage.** The spec's `MarketingKit` section is Task 1, its renderer is Task 2, committing captures is Task 3, the render entry point is Task 4, deleting frameit is Task 5, the step-summary images are Tasks 6 and 7, and the documentation is Task 8. The captions table is copied verbatim into Task 1 Step 3. The sequence in the spec has four steps; this plan splits them into eight so each ends with something testable.

**The one thing the spec left open** — whether `data:` URIs survive GitHub's summary sanitiser — is Task 7 Step 1, before any workflow depends on the answer.

**Placeholder scan.** No TBD or TODO. Task 7's workflow steps describe structure rather than quoting complete YAML, because the summary mechanism they contain is settled by Step 1 and writing all three out twice would guarantee one of them was stale; every other step carries its code.

**Type consistency.** `MarketingDevice.size` and `.capturePrefix`, `MarketingScreen.fileStem` and `.caption`, and `MarketingScreenshot(capture:screen:device:)` and `.render(capture:screen:device:)` are defined in Tasks 1 and 2 and used with those exact signatures in Task 4. The capture path `Screenshots/Captures/<locale>/<capturePrefix>-<fileStem>.png` is produced in Task 3 and consumed in Task 4 in that form.

**Not covered, deliberately.** iPad multi-column support, app preview videos and further languages are out of scope in the spec and have no tasks here.
