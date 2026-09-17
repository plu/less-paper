# App Store Preview Video Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and upload a 15–30 second App Store app preview for the 6.9" iPhone in en-US, recorded from the simulator with no manual step.

**Architecture:** An XCUITest in the existing `AppSnapshots` target walks a scripted seven-beat journey through the app running on the snapshot fixtures, printing two marker lines that say when the choreography started and ended. A mise task records the simulator from outside across that run, uses the markers to trim the recording, conforms it with ffmpeg to Apple's exact specification, and refuses anything App Store Connect would refuse. A fastlane lane uploads it.

**Tech Stack:** XCUITest, `xcrun simctl io recordVideo`, ffmpeg/ffprobe, Python 3 (stdlib `unittest`), fastlane `deliver`, mise tasks, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-17-app-preview-video-design.md`

## Global Constraints

- Output resolution is exactly **886 × 1920**. Not "about", not "at least".
- Duration must be **between 15 and 30 seconds** inclusive. Outside that range is a hard failure, never a truncation.
- Frame rate **at most 30 fps**. Video **H.264, High profile, Level 4.0 or below**.
- An **enabled stereo audio track** is mandatory: AAC, 256 kbps, 44.1 or 48 kHz. A simulator recording has none.
- The output filename must contain the literal string **`IPHONE_67`**. There is no `IPHONE_69` preview type; `IPHONE_67` is the 6.9" slot.
- Comments are `//` only, never `///` or `/** */`. See `AGENTS.md`.
- Committed path: `fastlane/app_previews/en-US/01_IPHONE_67.mp4`.
- Poster frame timecode: `00:00:18:00`.

## Deviations from the spec

Two, both discovered while mapping the spec onto the repository. Neither changes the design's shape.

**The validator lives in `mise/scripts/`, not `Screenshots/`.** The spec placed `verify_preview.py` beside `verify_captures.py`. But `mise/tasks/ci/lint:7` runs `python3 -m unittest discover -s "$MISE_PROJECT_ROOT/mise/scripts" -p "test_*.py"` — test discovery is rooted at `mise/scripts` and nowhere else. Putting the validator there means its tests run on every CI lint with no workflow change; putting it in `Screenshots/` means writing tests that never run. `verify_captures.py` has no tests, which is why its location never mattered.

**Beat 4 closes sheets rather than tapping Apply.** There is no Apply button. `DocumentFilterView.swift:224` and `DocumentFilterTagListView.swift:37` both dismiss with a `SheetCloseButton`, whose accessibility label is `.close` (`Modules/Components/Sheet/SheetCloseButton.swift:11`) — "Close" in English, "Schließen" in German. The filter applies live, so closing the two sheets is what reveals the narrowed list. `SnapshotLabels` needs a `close` field added.

## File Structure

| File | Responsibility |
|---|---|
| `mise/scripts/preview_check.py` | Given an ffprobe JSON dict and a filename, list every reason App Store Connect would refuse the file. Pure. |
| `mise/scripts/test_preview_check.py` | Tests for the above. |
| `mise/scripts/preview_window.py` | Given an xcodebuild log and the recorder's start time, compute the trim offset and duration. Pure. |
| `mise/scripts/test_preview_window.py` | Tests for the above. |
| `Modules/AppSnapshots/UITestNavigation.swift` | The navigation helpers and `SNAPSHOT_MODE` key, shared by both test classes. |
| `Modules/AppSnapshots/AppPreviewTests.swift` | The seven-beat choreography and its markers. |
| `Modules/AppSnapshots/SnapshotTests.swift` | Modified: helpers removed, adopts the protocol. |
| `Modules/AppSnapshots/SnapshotLabels.swift` | Modified: gains `close`. |
| `mise/tasks/preview/record` | Orchestrates build → record → test → trim → conform → check. |
| `mise/tasks/preview/upload` | Runs the fastlane lane with the App Store Connect key. |
| `fastlane/Fastfile` | Modified: `upload_previews` lane. |
| `fastlane/Snapfile` | Modified: `skip_testing` so screenshot runs skip the choreography. |
| `.github/workflows/preview-record.yml` | Manual workflow that records and opens a pull request. |

---

### Task 1: The output validator

**Files:**
- Create: `mise/scripts/preview_check.py`
- Test: `mise/scripts/test_preview_check.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `problems(probe: dict, name: str) -> list[str]` — every reason the file is unacceptable, empty when it is fine. `probe` is parsed `ffprobe -show_streams -show_format -of json` output.

- [ ] **Step 1: Write the failing tests**

```python
#!/usr/bin/env python3
"""Tests for preview_check.py.

Only the pure half is tested. Shelling out to ffprobe lives in main() and is exercised by running
the script for real.
"""

import unittest

from preview_check import problems

NAME = "01_IPHONE_67.mp4"


def probe(**overrides):
    """A conforming probe, with named fields swapped out per test."""
    video = {
        "codec_type": "video",
        "codec_name": "h264",
        "profile": "High",
        "level": 40,
        "width": 886,
        "height": 1920,
        "r_frame_rate": "30/1",
    }
    audio = {
        "codec_type": "audio",
        "codec_name": "aac",
        "channels": 2,
        "sample_rate": "44100",
        "disposition": {"default": 1},
    }
    video.update(overrides.pop("video", {}))
    audio.update(overrides.pop("audio", {}))
    streams = [video] if overrides.pop("no_audio", False) else [video, audio]
    return {"streams": streams, "format": {"duration": overrides.pop("duration", "26.0")}}


class ProblemsTests(unittest.TestCase):

    def test_a_conforming_file_has_no_problems(self):
        self.assertEqual(problems(probe(), NAME), [])

    def test_one_pixel_too_wide_is_refused(self):
        self.assertIn("886x1920", problems(probe(video={"width": 887}), NAME)[0])

    def test_one_pixel_too_tall_is_refused(self):
        self.assertIn("886x1920", problems(probe(video={"height": 1921}), NAME)[0])

    def test_thirty_one_seconds_is_refused(self):
        self.assertIn("duration", problems(probe(duration="31.0"), NAME)[0])

    def test_fourteen_seconds_is_refused(self):
        self.assertIn("duration", problems(probe(duration="14.0"), NAME)[0])

    def test_fifteen_and_thirty_seconds_are_accepted(self):
        self.assertEqual(problems(probe(duration="15.0"), NAME), [])
        self.assertEqual(problems(probe(duration="30.0"), NAME), [])

    def test_sixty_fps_is_refused(self):
        self.assertIn("frame rate", problems(probe(video={"r_frame_rate": "60/1"}), NAME)[0])

    def test_level_41_is_refused(self):
        self.assertIn("level", problems(probe(video={"level": 41}), NAME)[0])

    def test_main_profile_is_refused(self):
        self.assertIn("profile", problems(probe(video={"profile": "Main"}), NAME)[0])

    def test_a_missing_audio_track_is_refused(self):
        self.assertIn("audio", problems(probe(no_audio=True), NAME)[0])

    def test_mono_audio_is_refused(self):
        self.assertIn("stereo", problems(probe(audio={"channels": 1}), NAME)[0])

    def test_a_disabled_audio_track_is_refused(self):
        self.assertIn("enabled", problems(probe(audio={"disposition": {"default": 0}}), NAME)[0])

    def test_an_odd_sample_rate_is_refused(self):
        self.assertIn("sample rate", problems(probe(audio={"sample_rate": "22050"}), NAME)[0])

    def test_a_name_without_the_device_type_is_refused(self):
        self.assertIn("IPHONE_67", problems(probe(), "01_preview.mp4")[0])

    def test_every_problem_is_reported_not_just_the_first(self):
        found = problems(probe(video={"width": 100}, duration="99.0", no_audio=True), "x.mp4")
        self.assertEqual(len(found), 4)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mise/scripts && python3 -m unittest test_preview_check -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'preview_check'`

- [ ] **Step 3: Write the implementation**

```python
#!/usr/bin/env python3
"""Refuse a preview App Store Connect would refuse.

    python3 mise/scripts/preview_check.py fastlane/app_previews/en-US/01_IPHONE_67.mp4

deliver checks the resolution and nothing else, and App Store Connect only says no once the upload
has already happened. Every limit here is published and stable, so the whole class of rejection is
catchable on a laptop.
"""

import json
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

# https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications
SIZE = (886, 1920)
DURATION = (15.0, 30.0)
MAX_FPS = 30
MAX_LEVEL = 40
SAMPLE_RATES = {"44100", "48000"}

# There is no IPHONE_69 preview type: spaceship's enumeration stops at IPHONE_67 and maps it to
# 886x1920, which is the 6.9" size. deliver matches the type by substring, so a name without it
# uploads nothing and says nothing.
DEVICE_TYPE = "IPHONE_67"


def stream(probe, kind):
    for candidate in probe.get("streams", []):
        if candidate.get("codec_type") == kind:
            return candidate
    return None


def problems(probe, name):
    found = []

    video = stream(probe, "video")
    if not video:
        found.append("there is no video stream")
    else:
        size = (video.get("width"), video.get("height"))
        if size != SIZE:
            found.append(f"the resolution is {size[0]}x{size[1]}, and must be exactly 886x1920")

        # r_frame_rate is a rational ("30/1"), not a float.
        fps = float(Fraction(video.get("r_frame_rate", "0/1")))
        if fps > MAX_FPS:
            found.append(f"the frame rate is {fps:g}, and must be at most 30")

        if video.get("codec_name") != "h264":
            found.append(f"the video codec is {video.get('codec_name')}, and must be h264")
        if video.get("profile") != "High":
            found.append(f"the H.264 profile is {video.get('profile')}, and must be High")
        if (video.get("level") or 0) > MAX_LEVEL:
            found.append(f"the H.264 level is {video.get('level')}, and must be 4.0 or below")

    audio = stream(probe, "audio")
    if not audio:
        # The one that catches everybody: a simulator recording has no audio track at all, and a
        # preview without one is refused on upload.
        found.append("there is no audio stream, and App Store Connect requires one")
    else:
        if audio.get("channels") != 2:
            found.append(f"the audio has {audio.get('channels')} channels, and must be stereo")
        if str(audio.get("sample_rate")) not in SAMPLE_RATES:
            found.append(
                f"the audio sample rate is {audio.get('sample_rate')}, and must be 44100 or 48000"
            )
        if not audio.get("disposition", {}).get("default"):
            found.append("the audio track is not enabled, and every track must be")

    duration = float(probe.get("format", {}).get("duration", 0))
    if not DURATION[0] <= duration <= DURATION[1]:
        found.append(f"the duration is {duration:.1f}s, and must be between 15 and 30")

    if DEVICE_TYPE not in name.upper():
        found.append(f"the filename does not contain {DEVICE_TYPE}, so deliver would skip it")

    return found


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: preview_check.py <video>")

    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"error: no such file: {path}")

    probe = json.loads(
        subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-show_streams", "-show_format",
                "-of", "json", str(path),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    )

    found = problems(probe, path.name)
    if found:
        print(f"{path.name} would be refused:", file=sys.stderr)
        for problem in found:
            print(f"  - {problem}", file=sys.stderr)
        raise SystemExit(1)

    print(f"{path.name} meets every App Store Connect requirement.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mise/scripts && python3 -m unittest test_preview_check -v`
Expected: PASS, 15 tests.

- [ ] **Step 5: Confirm the repo's lint task discovers them**

Run: `mise run ci:lint`
Expected: the unittest discovery step reports the new tests among the total.

- [ ] **Step 6: Commit**

```bash
git add mise/scripts/preview_check.py mise/scripts/test_preview_check.py
git commit -m "feat: refuse an App Store preview the store would refuse"
```

---

### Task 2: The trim window

**Files:**
- Create: `mise/scripts/preview_window.py`
- Test: `mise/scripts/test_preview_window.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `window(log: str, recorder_started: float) -> tuple[float, float]` returning `(start_offset, duration)` in seconds, raising `ValueError` with a readable message when the log cannot yield a usable window.

- [ ] **Step 1: Write the failing tests**

```python
#!/usr/bin/env python3
"""Tests for preview_window.py."""

import unittest

from preview_window import window

STARTED = 1_000_000.0


def log(start=1_000_002.5, end=1_000_028.5, extra=""):
    return (
        "Test Suite 'AppPreviewTests' started\n"
        f"PREVIEW_MARKER start {start}\n"
        "    t =     1.20s Tap \"Filter\"\n"
        f"{extra}"
        f"PREVIEW_MARKER end {end}\n"
        "Test Suite 'AppPreviewTests' passed\n"
    )


class WindowTests(unittest.TestCase):

    def test_offsets_are_measured_from_when_the_recorder_started(self):
        self.assertEqual(window(log(), STARTED), (2.5, 26.0))

    def test_a_missing_start_marker_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "start"):
            window("PREVIEW_MARKER end 1000028.5\n", STARTED)

    def test_a_missing_end_marker_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "end"):
            window("PREVIEW_MARKER start 1000002.5\n", STARTED)

    def test_an_empty_log_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "start"):
            window("", STARTED)

    def test_a_run_longer_than_thirty_seconds_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "31.0s"):
            window(log(end=1_000_033.5), STARTED)

    def test_a_run_shorter_than_fifteen_seconds_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "10.0s"):
            window(log(end=1_000_012.5), STARTED)

    def test_a_start_before_the_recorder_is_an_error(self):
        # The clocks are shared, so this means the recorder started late and the opening beat is
        # not in the file at all.
        with self.assertRaisesRegex(ValueError, "before the recording"):
            window(log(start=999_999.0, end=1_000_020.0), STARTED)

    def test_overrun_lines_are_ignored(self):
        self.assertEqual(
            window(log(extra="PREVIEW_OVERRUN pdf 0.8\n"), STARTED),
            (2.5, 26.0),
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mise/scripts && python3 -m unittest test_preview_window -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'preview_window'`

- [ ] **Step 3: Write the implementation**

```python
#!/usr/bin/env python3
"""Find the choreography inside the recording.

    python3 mise/scripts/preview_window.py <xcodebuild-log> <recorder-start-epoch>

Prints "<start-offset> <duration>" for ffmpeg to trim by.

simctl records from the host while the choreography runs in the simulator, so the window between
them has to be found rather than assumed. The test prints two markers; the simulator shares the
host's clock, so subtracting the moment the recorder started gives exact offsets. Polling for the
app process and trimming a fixed lead-in instead would drift with runner load, and two seconds of
drift opens the video mid-transition.
"""

import re
import sys
from pathlib import Path

MARKER = re.compile(r"^PREVIEW_MARKER (start|end) (\d+(?:\.\d+)?)", re.MULTILINE)

DURATION = (15.0, 30.0)


def window(log, recorder_started):
    marks = {}
    for name, value in MARKER.findall(log):
        # First start, last end: a retried test would print more than one pair, and the outermost
        # bracket is the one that contains the whole journey.
        if name == "start":
            marks.setdefault(name, float(value))
        else:
            marks[name] = float(value)

    for name in ("start", "end"):
        if name not in marks:
            raise ValueError(
                f"the log has no PREVIEW_MARKER {name} line - the choreography did not "
                f"reach the {name} of its run"
            )

    offset = marks["start"] - recorder_started
    if offset < 0:
        raise ValueError(
            "the choreography started before the recording did, so its opening is not in the file"
        )

    duration = marks["end"] - marks["start"]
    if not DURATION[0] <= duration <= DURATION[1]:
        raise ValueError(
            f"the choreography ran for {duration:.1f}s, and App Store Connect takes 15s to 30s. "
            f"Retune the marks in AppPreviewTests rather than trimming to fit."
        )

    return offset, duration


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: preview_window.py <xcodebuild-log> <recorder-start-epoch>")

    try:
        offset, duration = window(
            Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"),
            float(sys.argv[2]),
        )
    except ValueError as error:
        raise SystemExit(f"error: {error}")

    print(f"{offset:.3f} {duration:.3f}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd mise/scripts && python3 -m unittest test_preview_window -v`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add mise/scripts/preview_window.py mise/scripts/test_preview_window.py
git commit -m "feat: locate the choreography inside a simulator recording"
```

---

### Task 3: Share the navigation helpers

**Files:**
- Create: `Modules/AppSnapshots/UITestNavigation.swift`
- Modify: `Modules/AppSnapshots/SnapshotTests.swift` (remove lines 1-16 and the private helpers at 134-170)
- Modify: `Modules/AppSnapshots/SnapshotLabels.swift` (add `close`)

**Interfaces:**
- Consumes: nothing.
- Produces: `protocol UITestNavigation` with `var labels: SnapshotLabels { get }`, and extension members `timeout: TimeInterval`, `makeApp() -> XCUIApplication`, `tapTab(_:in:) -> Bool`, `openDocuments(in:) -> Bool`, `openFilter(in:) -> Bool`, `openFeaturedDocument(in:) -> Bool`. Also `enum SnapshotEnvironment { static let key }`.

- [ ] **Step 1: Add `close` to `SnapshotLabels`**

Three edits to `Modules/AppSnapshots/SnapshotLabels.swift`, keeping its alphabetical order. Values copied from `Modules/Components/Resources/Localizable.xcstrings`, key `close`.

```swift
    static let english = Self(
        close: "Close",
        documents: "Documents",
        // ... the rest unchanged
    )

    static let german = Self(
        close: "Schließen",
        documents: "Dokumente",
        // ... the rest unchanged
    )

    let close: String
    let documents: String
    // ... the rest unchanged
```

- [ ] **Step 2: Create the shared file**

```swift
import UITestSupport
import XCTest

// Matches SnapshotConfiguration.environmentKey. This target cannot import SnapshotSupport, which is
// DEBUG-only app code, so the two are kept in step by name.
enum SnapshotEnvironment {
    static let key = "SNAPSHOT_MODE"
}

// Shared by the two things that walk the app on fixtures: SnapshotTests, which stops on each screen
// to capture a frame, and AppPreviewTests, which walks straight through recording a video.
@MainActor
protocol UITestNavigation {
    var labels: SnapshotLabels { get }
}

@MainActor
extension UITestNavigation {

    var timeout: TimeInterval { 30.0 }

    // Returns the app unlaunched: SnapshotTests has to hand it to fastlane's setupSnapshot before
    // it starts, and AppPreviewTests must not, because no fastlane run is driving it.
    func makeApp() -> XCUIApplication {
        let app = XCUIApplication()

        // Set here rather than left to the scheme: a scheme's test-action environment reaches the
        // test runner, not the app it launches. Without it the app opens on the add-server screen
        // and every capture fails looking for a tab bar.
        app.launchEnvironment[SnapshotEnvironment.key] = "true"
        return app
    }

    // Not app.tabBars: iPadOS renders the tabs as a segmented bar along the top, which is not a tab
    // bar element, so a tab bar lookup finds nothing there. A plain button matches on both.
    func tapTab(_ label: String, in app: XCUIApplication) -> Bool {
        let tab = app.buttons[label].firstMatch
        guard tab.waitUntilHittable(timeout: timeout) else {
            return false
        }
        tab.tap()
        return true
    }

    func openDocuments(in app: XCUIApplication) -> Bool {
        guard tapTab(labels.documents, in: app) else {
            return false
        }
        return app.cells.firstMatch.waitForExistence(timeout: timeout)
    }

    func openFilter(in app: XCUIApplication) -> Bool {
        let filter = app.buttons[labels.filter].firstMatch
        guard filter.waitUntilHittable(timeout: timeout) else {
            return false
        }
        filter.tap()

        // The search field rather than the Apply button: it is the element the sheet is built
        // around, and it is present as soon as the sheet is.
        return app.textFields[labels.titleAndContent].firstMatch.waitForExistence(timeout: timeout)
    }

    // The first row rather than a title: the corpus differs by language, and SnapshotCorpus puts
    // the document these two screenshots want at the top for exactly this reason.
    func openFeaturedDocument(in app: XCUIApplication) -> Bool {
        guard openDocuments(in: app) else {
            return false
        }
        let row = app.cells.firstMatch
        guard row.waitUntilHittable(timeout: timeout) else {
            return false
        }
        row.tap()
        return true
    }
}
```

- [ ] **Step 3: Strip `SnapshotTests.swift` down to its captures**

Delete the `SnapshotEnvironment` enum at the top (it moved), and delete `timeout`, `launch`, `tapTab`, `openDocuments`, `openFilter`, `openFeaturedDocument` from the private section. Change the declaration to `final class SnapshotTests: XCTestCase, UITestNavigation`, make `labels` non-private (the protocol requires it), and replace the deleted `launch()` with this private one, which keeps the fastlane wiring that only the capture needs:

```swift
    private func launch() -> XCUIApplication {
        let app = makeApp()
        setupSnapshot(app)
        app.launch()
        return app
    }
```

`labels` keeps its body, losing only its `private`:

```swift
    // setupSnapshot fills Snapshot.deviceLanguage from the language fastlane is currently
    // capturing, so the labels follow the run rather than needing a switch of their own.
    var labels: SnapshotLabels {
        SnapshotLabels.current(Snapshot.deviceLanguage)
    }
```

- [ ] **Step 4: Verify the screenshot target still builds**

Run: `mise run generate && xcodebuild build-for-testing -workspace LessPaper.xcworkspace -scheme Snapshots -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' | xcbeautify`
Expected: BUILD SUCCEEDED. This is a pure move — no behaviour changed, so a clean build is the whole check.

- [ ] **Step 5: Verify one capture still captures**

Run: `xcodebuild test-without-building -workspace LessPaper.xcworkspace -scheme Snapshots -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:AppSnapshots/SnapshotTests/testDocuments | xcbeautify`
Expected: the test passes. It exercises `makeApp`, `tapTab` and `openDocuments` through their new home.

- [ ] **Step 6: Commit**

```bash
git add Modules/AppSnapshots
git commit -m "refactor: share the snapshot navigation helpers"
```

---

### Task 4: The choreography

**Files:**
- Create: `Modules/AppSnapshots/AppPreviewTests.swift`
- Modify: `fastlane/Snapfile`

**Interfaces:**
- Consumes: `UITestNavigation` from Task 3 — `makeApp()`, `tapTab(_:in:)`, `openFilter(in:)`, `timeout`, `labels`.
- Produces: the test `AppSnapshots/AppPreviewTests/testRecordPreview`, which prints `PREVIEW_MARKER start <epoch>` and `PREVIEW_MARKER end <epoch>` — the lines `preview_window.py` from Task 2 parses.

- [ ] **Step 1: Write the choreography**

```swift
import UITestSupport
import XCTest

// Records the App Store preview. Not a test: nothing here asserts about the app, and a failure means
// a beat could not be reached rather than that the app is wrong.
//
// The recording is taken from outside by mise/tasks/preview/record, which cannot see inside the
// simulator. This side's whole contract with it is the two marker lines: everything between them is
// the video.
@MainActor
final class AppPreviewTests: XCTestCase, UITestNavigation {

    func testRecordPreview() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(openDocuments(in: app), "Could not open the Documents tab")

        let start = Date()
        mark("start", at: start)

        // Beat 1 - the list, scrolled. press-then-drag rather than swipeUp: a swipe is flung and
        // lands in a blur, which reads as a glitch at thumbnail size.
        //
        // Coordinates rather than elements: a drag from a cell to itself covers no distance and
        // scrolls nothing, and the cell that starts under the finger is not the one that ends there.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        from.press(forDuration: 0.3, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        hold(until: 4, from: start, beat: "list")

        // Beat 2 - the filter sheet.
        XCTAssertTrue(openFilter(in: app), "Could not open the filter sheet")
        hold(until: 8, from: start, beat: "filter")

        // Beat 3 - the tag picker, with one tag chosen. The tag field is a tap gesture rather than a
        // button, so it is matched as a label.
        let tagField = app.staticTexts[labels.tag].firstMatch
        XCTAssertTrue(tagField.waitForExistence(timeout: timeout), "The filter sheet showed no tag field")
        tagField.tap()

        XCTAssertTrue(
            app.buttons[labels.notAssigned].firstMatch.waitForExistence(timeout: timeout),
            "The tag sheet never appeared"
        )

        // Not localised: tags are server data, and Screenshots/Fixtures/tags.json carries the same
        // eleven names in every language. "Important" is four documents, which narrows the list
        // visibly without emptying it.
        let tag = app.buttons[Self.featuredTag].firstMatch
        XCTAssertTrue(tag.waitUntilHittable(timeout: timeout), "The tag sheet did not list \(Self.featuredTag)")
        tag.tap()
        hold(until: 12, from: start, beat: "tags")

        // Beat 4 - back to the narrowed list. There is no Apply button: the filter applies live, so
        // closing the two sheets is what reveals the result.
        closeSheet(in: app)
        closeSheet(in: app)
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout), "The filtered list came back empty")
        hold(until: 16, from: start, beat: "filtered")

        // Beat 5 - a document, open.
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitUntilHittable(timeout: timeout), "The filtered list had no tappable row")
        row.tap()
        XCTAssertTrue(
            app.otherElements["PDF"].waitForExistence(timeout: timeout),
            "The document detail never rendered a PDF"
        )
        hold(until: 20, from: start, beat: "pdf")

        // Beat 6 - editing it where it is being read.
        let edit = app.navigationBars.buttons[labels.edit].firstMatch
        XCTAssertTrue(edit.waitUntilHittable(timeout: timeout), "The detail screen showed no Edit button")
        edit.tap()
        XCTAssertTrue(
            app.staticTexts[labels.editDocument].waitForExistence(timeout: timeout),
            "The edit sheet never appeared"
        )
        hold(until: 24, from: start, beat: "edit")

        // Beat 7 - back to the document, and rest there. The last frame is the one a viewer is left
        // with, so it is the document rather than a form.
        closeSheet(in: app)
        hold(until: 26, from: start, beat: "rest")

        mark("end", at: Date())
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Private

    private static let featuredTag = "Important"

    // One locale, so the label table is asked for it directly rather than through
    // Snapshot.deviceLanguage, which is empty when no fastlane run is driving.
    var labels: SnapshotLabels {
        SnapshotLabels.english
    }

    // Beats are scheduled against the start, never chained. Chaining would make the total duration
    // the sum of the dwells *plus* however long six screens took to settle, which on a loaded runner
    // is a coin flip against the 30s ceiling. Scheduling puts the cost of a slow settle inside that
    // beat's own slot: the video still ends at 0:26, that beat is just held for less.
    private func hold(until elapsed: TimeInterval, from start: Date, beat: String) {
        let remaining = elapsed - Date().timeIntervalSince(start)
        guard remaining > 0 else {
            // Logged, not failed: one overrun beat still yields a usable video, and the number is
            // what the marks get retuned against. An overrun big enough to matter fails later, when
            // preview_window.py finds the run outside 15-30s.
            print("PREVIEW_OVERRUN \(beat) \(-remaining)")
            return
        }
        Thread.sleep(forTimeInterval: remaining)
    }

    private func mark(_ name: String, at date: Date) {
        print("PREVIEW_MARKER \(name) \(date.timeIntervalSince1970)")
    }

    private func closeSheet(in app: XCUIApplication) {
        let close = app.buttons[labels.close].firstMatch
        XCTAssertTrue(close.waitUntilHittable(timeout: timeout), "No close button on the sheet")
        close.tap()
    }
}
```

- [ ] **Step 2: Keep it out of screenshot runs**

Append to `fastlane/Snapfile`:

```ruby
# The preview choreography lives in the same target because it needs the same fixtures and the same
# navigation. It captures nothing, so a screenshot run would spend two minutes on it four times over
# - twice per device, twice per language - for no image.
skip_testing(["AppSnapshots/AppPreviewTests"])
```

- [ ] **Step 3: Run the choreography and read its markers**

Run:
```bash
mise run generate
xcodebuild test-without-building -workspace LessPaper.xcworkspace -scheme Snapshots \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:AppSnapshots/AppPreviewTests | tee /tmp/preview.log | xcbeautify
grep PREVIEW_ /tmp/preview.log
```
Expected: the test passes; exactly one `PREVIEW_MARKER start` and one `PREVIEW_MARKER end`, roughly 26 seconds apart. `PREVIEW_OVERRUN` lines are a signal to widen those beats' marks, not a failure.

- [ ] **Step 4: Check the window computes**

Run: `cd mise/scripts && python3 preview_window.py /tmp/preview.log $(python3 -c "print(0)")`
Expected: two numbers, the second between 15 and 30. (A zero recorder start makes the first number a raw epoch — this step is checking the duration and that parsing works, not the offset.)

- [ ] **Step 5: Confirm screenshots skip it**

Run: `grep -A2 skip_testing fastlane/Snapfile`
Expected: the entry is present. A full capture run is an hour and is not worth spending here; `verify_captures.py` in the record workflow is what catches a capture set gone wrong.

- [ ] **Step 6: Commit**

```bash
git add Modules/AppSnapshots/AppPreviewTests.swift fastlane/Snapfile
git commit -m "feat: choreograph the App Store preview"
```

---

### Task 5: Record, trim and conform

**Files:**
- Create: `mise/tasks/preview/record`
- Modify: `Brewfile`, `.gitattributes`

**Interfaces:**
- Consumes: `preview_window.py` and `preview_check.py` from Tasks 1-2, `AppPreviewTests` from Task 4.
- Produces: `fastlane/app_previews/en-US/01_IPHONE_67.mp4`, conforming.

- [ ] **Step 1: Add the tooling**

Append `brew "ffmpeg"` to `Brewfile`, beside the imagemagick that already serves `screenshots:frame`. Append to `.gitattributes`:

```
*.mp4 filter=lfs diff=lfs merge=lfs -text
```

Run `brew bundle` and confirm with `ffmpeg -version` and `ffprobe -version`.

- [ ] **Step 2: Write the task**

```bash
#!/usr/bin/env bash
#MISE description="Record the App Store preview into fastlane/app_previews"
set -euo pipefail

# Runs against the fixtures in Screenshots/, never a server, so no container is needed - the same
# SNAPSHOT_MODE the screenshots use.
#
# simctl records from out here while the choreography runs in there, so the two are stitched by the
# markers AppPreviewTests prints rather than by assumption. See the design doc for why.

DEVICE="iPhone 17 Pro Max"
SCRIPTS="$MISE_PROJECT_ROOT/mise/scripts"
OUT="$MISE_PROJECT_ROOT/fastlane/app_previews/en-US/01_IPHONE_67.mp4"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

tuist install
tuist generate --no-open

# Built first and separately: a build inside the recorded window would put minutes of a static
# simulator into the file, and its duration would depend on the state of the derived data.
xcodebuild build-for-testing \
  -workspace "$MISE_PROJECT_ROOT/LessPaper.xcworkspace" \
  -scheme Snapshots \
  -destination "platform=iOS Simulator,name=$DEVICE" | xcbeautify

udid=$(xcrun simctl list devices -j | jq -r --arg name "$DEVICE" '
  [.devices[][] | select(.name == $name and .isAvailable)] | first.udid // ""
')
[ -n "$udid" ] && [ "$udid" != "null" ] || {
  echo "error: no available simulator named $DEVICE - run 'mise run simulators:prepare'" >&2
  exit 1
}

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b

# 9:41, full bars, full battery. The Snapfile asks fastlane for this on a screenshot run; nothing
# does it for a run driven by hand.
xcrun simctl status_bar "$udid" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# --mask ignored gives a plain rectangle. With the mask applied the corners come out rounded and
# transparent, which is not what the store slot wants.
started=$(python3 -c 'import time; print(time.time())')
xcrun simctl io "$udid" recordVideo --codec h264 --mask ignored --force "$WORK/raw.mov" &
recorder=$!

# The recorder needs a moment to attach before the first frame is real.
sleep 2

set +e
xcodebuild test-without-building \
  -workspace "$MISE_PROJECT_ROOT/LessPaper.xcworkspace" \
  -scheme Snapshots \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -only-testing:AppSnapshots/AppPreviewTests > "$WORK/xcodebuild.log" 2>&1
status=$?
set -e

# SIGINT rather than SIGKILL: simctl finalises the container on interrupt, and a killed recorder
# leaves an unreadable file.
kill -INT "$recorder" 2>/dev/null || true
wait "$recorder" 2>/dev/null || true

xcrun simctl status_bar "$udid" clear

if [ "$status" -ne 0 ]; then
  echo "error: the choreography failed - the last lines of its log:" >&2
  tail -40 "$WORK/xcodebuild.log" >&2
  exit "$status"
fi

grep PREVIEW_OVERRUN "$WORK/xcodebuild.log" || true

read -r offset duration < <(python3 "$SCRIPTS/preview_window.py" "$WORK/xcodebuild.log" "$started")
echo "Trimming from ${offset}s for ${duration}s."

mkdir -p "$(dirname "$OUT")"

# scale then crop, never pad: 1320x2868 scaled to width 886 is 1926, six pixels too tall, and three
# rows off each end is invisible where black bars down a store listing would not be.
#
# anullsrc supplies the silent stereo track. Apple requires an enabled audio track and a simulator
# recording has none, which is the single most common reason a preview is refused.
ffmpeg -y -loglevel error \
  -ss "$offset" -i "$WORK/raw.mov" -t "$duration" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -vf "scale=886:-2,crop=886:1920" \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
  -r 30 -b:v 11M -maxrate 12M -bufsize 24M \
  -c:a aac -b:a 256k -ar 44100 -ac 2 \
  -movflags +faststart -shortest \
  "$OUT"

python3 "$SCRIPTS/preview_check.py" "$OUT"
echo "Wrote $OUT"
```

- [ ] **Step 3: Record one for real**

Run: `mise run preview:record`
Expected: it finishes with `01_IPHONE_67.mp4 meets every App Store Connect requirement.` and `Wrote …`.

- [ ] **Step 4: Watch it**

Run: `open fastlane/app_previews/en-US/01_IPHONE_67.mp4`
Expected: the seven beats, opening on the document list and resting on the document. This is the step no assertion replaces — if a beat opens mid-transition, retune that mark in `AppPreviewTests` and record again.

- [ ] **Step 5: Confirm it went to LFS**

Run: `git add fastlane/app_previews && git check-attr filter -- fastlane/app_previews/en-US/01_IPHONE_67.mp4`
Expected: `filter: lfs`.

- [ ] **Step 6: Commit**

```bash
git add Brewfile .gitattributes mise/tasks/preview/record fastlane/app_previews
git commit -m "feat: record the App Store preview end to end"
```

---

### Task 6: Upload

**Files:**
- Modify: `fastlane/Fastfile`
- Create: `mise/tasks/preview/upload`

**Interfaces:**
- Consumes: the `.mp4` from Task 5.
- Produces: the `upload_previews` lane, and `mise run preview:upload`.

- [ ] **Step 1: Add the constant and the lane**

Beside the existing `SCREENSHOTS` constant near the top of `fastlane/Fastfile`:

```ruby
# What deliver uploads as the app preview. Committed, unlike SCREENSHOTS, because there is no
# framing step between the recording and the thing that ships.
APP_PREVIEWS = File.expand_path("app_previews", __dir__)
```

And the lane, beside `upload_screenshots`:

```ruby
# Previews only. The build ships through altool in mise/tasks/ci/upload and the text through
# upload_metadata, so this touches neither - the same separation those two keep from each other.
desc "Upload the App Store preview video to App Store Connect"
lane :upload_previews do
  deliver(
    # Setting this is what turns on Deliver::SyncAppPreviews; there is no skip_previews to pair
    # with it, so the path's presence is the whole switch.
    app_previews_path: APP_PREVIEWS,
    # 0:18 is the middle of the beat holding the rendered PDF. Apple's 5s default lands
    # mid-transition, while the filter sheet is still rising.
    preview_frame_time_code: "00:00:18:00",
    overwrite_preview_videos: true,
    # Skips the HTML preview, which otherwise waits for a keypress nobody is there to give.
    force: true,
    # As with the screenshot upload: a preview upload must not decide how the version rolls out.
    automatic_release: nil,
    skip_binary_upload: true,
    skip_metadata: true,
    skip_screenshots: true,
    run_precheck_before_submit: false
  )
end
```

- [ ] **Step 2: Write the task**

```bash
#!/usr/bin/env bash
#MISE description="Upload the App Store preview video to App Store Connect"
set -euo pipefail

# The same App Store Connect key mise/tasks/ci/upload uses for altool. deliver is told to skip the
# binary, the metadata and the screenshots, so this touches nothing but the preview.
bundle config set --local path vendor/bundle
bundle check >/dev/null 2>&1 || bundle install

# Checked here as well as at record time: this is the last gate before the file leaves the machine,
# and the committed file may not be the one this checkout just recorded.
python3 "$MISE_PROJECT_ROOT/mise/scripts/preview_check.py" \
  "$MISE_PROJECT_ROOT/fastlane/app_previews/en-US/01_IPHONE_67.mp4"

ASC_KEY_ID="$ALTOOL_KEY_ID" \
ASC_ISSUER_ID="$ALTOOL_ISSUER_ID" \
ASC_AUTH_KEY="$ALTOOL_AUTH_KEY" \
  bundle exec fastlane upload_previews
```

- [ ] **Step 3: Check the lane parses**

Run: `bundle exec fastlane lanes`
Expected: `upload_previews` is listed with its description. This validates the Ruby without contacting Apple.

- [ ] **Step 4: Check the preflight refuses a bad file**

Run:
```bash
cp fastlane/app_previews/en-US/01_IPHONE_67.mp4 /tmp/wrong_name.mp4
python3 mise/scripts/preview_check.py /tmp/wrong_name.mp4; echo "exit: $?"
```
Expected: exit 1, reporting that the filename does not contain `IPHONE_67`.

- [ ] **Step 5: Commit**

```bash
git add fastlane/Fastfile mise/tasks/preview/upload
git commit -m "feat: upload the App Store preview"
```

---

### Task 7: The record workflow

**Files:**
- Create: `.github/workflows/preview-record.yml`
- Create: `mise/tasks/ci/preview/record`

**Interfaces:**
- Consumes: `mise run preview:record` from Task 5.
- Produces: a manually dispatched workflow that opens a pull request with a new recording.

- [ ] **Step 1: Write the CI task**

```bash
#!/usr/bin/env bash
#MISE description="Record the App Store preview for CI"
set -euo pipefail

# Same work as preview:record. It exists under ci: so a workflow has one obvious entry point, and so
# the two can diverge later without the local task growing CI-only concerns.

# ci:clean wipes untracked files, vendor/bundle included, so the gems are installed per run rather
# than assumed. bundle check keeps that to a no-op when they are already there.
bundle config set --local path vendor/bundle
bundle check >/dev/null 2>&1 || bundle install

mise run preview:record
```

- [ ] **Step 2: Write the workflow**

```yaml
name: Preview - Record

# Manual only. It never pushes to main - a re-record changes what the store will show, so it arrives
# as a pull request and gets looked at like one. Unlike the screenshots, the artifact cannot be shown
# in the job summary: GitHub renders images there, not video, so the run artifact is how it gets
# watched before merging.
on:
  workflow_dispatch:

# Queued rather than cancelled, so a run already underway keeps its simulator time.
concurrency:
  group: preview-record
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write

defaults:
  run:
    shell: /bin/bash --noprofile --norc -euo pipefail {0}

env:
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

jobs:
  record:
    name: Record
    runs-on: [self-hosted, macOS]
    timeout-minutes: 60

    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          clean: false
          lfs: true

      - name: mise
        uses: jdx/mise-action@v4
        with:
          cache: false
          cache_save: false

      - run: mise ci:clean

      - run: mise simulators:prepare

      - run: mise run ci:preview:record

      - name: Upload the preview artifact
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: preview-${{ github.run_id }}-${{ github.run_attempt }}
          path: fastlane/app_previews/en-US/*.mp4
          retention-days: 14
          if-no-files-found: warn

      - name: Open a pull request with the new preview
        run: |
          branch="preview/record-${{ github.run_id }}"
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git checkout -b "$branch"
          git add fastlane/app_previews

          if git diff --cached --quiet; then
            echo "The preview is unchanged; nothing to open a pull request for." \
              >> "$GITHUB_STEP_SUMMARY"
            exit 0
          fi

          git commit -m "chore: re-record the App Store preview"
          git push origin "$branch"

          # The branch is the valuable part - it holds the simulator time. Opening the pull request
          # is a convenience, and GitHub blocks it unless "Allow GitHub Actions to create and approve
          # pull requests" is enabled, which no amount of `permissions:` overrides. A blocked
          # convenience must not discard the work, so this reports and carries on.
          if gh pr create --title "chore: re-record the App Store preview" \
            --body "Recorded by [run ${{ github.run_id }}](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}). Download the run artifact, watch it, then merge." \
            --head "$branch"
          then
            echo "Pull request opened." >> "$GITHUB_STEP_SUMMARY"
          else
            {
              echo "### The preview is on \`$branch\`"
              echo
              echo "Opening the pull request was refused. Enable **Settings → Actions → General →"
              echo "Allow GitHub Actions to create and approve pull requests**, or open it here:"
              echo
              echo "${{ github.server_url }}/${{ github.repository }}/compare/$branch?expand=1"
            } >> "$GITHUB_STEP_SUMMARY"
          fi

      - name: Summary
        if: always()
        run: |
          {
            echo "## Preview"
            echo
            echo "Video cannot be embedded in a job summary. Download the run artifact to watch it."
          } >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 3: Check the workflow is valid YAML that Actions accepts**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/preview-record.yml'))" && gh workflow list`
Expected: no parse error; after pushing the branch, `Preview - Record` appears in the list.

- [ ] **Step 4: Run the full lint**

Run: `mise run ci:lint`
Expected: PASS, including the Python tests from Tasks 1-2.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/preview-record.yml mise/tasks/ci/preview/record
git commit -m "ci: record the App Store preview on demand"
```

- [ ] **Step 6: Dispatch it once**

Run: `gh workflow run "Preview - Record" --ref feat/app-preview-video`
Expected: the run completes, the artifact is attached, and either a pull request opens or the summary explains why it could not. This is the only step that proves the self-hosted runner has ffmpeg — everything before it proved it on a laptop.

---

## Verification

The plan is done when:

- `mise run ci:lint` passes, including 23 new Python tests.
- `mise run preview:record` produces a file `preview_check.py` accepts.
- Somebody has watched the video and thinks it reads well.
- `bundle exec fastlane lanes` lists `upload_previews`.
- The workflow has been dispatched once and produced an artifact.

`mise run preview:upload` is deliberately not part of this: it puts the preview in front of Apple, which is the point at which the open question in the spec's Risks section — whether simulator footage is accepted at all — finally gets answered. That is a decision to take deliberately, not a step to tick off.
