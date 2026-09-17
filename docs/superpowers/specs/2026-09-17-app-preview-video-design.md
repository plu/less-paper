# An App Store preview that records itself

A 15–30 second App Store app preview for the 6.9" iPhone in en-US, choreographed as an XCUITest
against the existing snapshot fixtures, recorded from the simulator, conformed to Apple's
specification with ffmpeg, committed to the repository, and uploaded by `deliver` — with no step that
needs a person holding a phone.

## Context

The listing has screenshots and no preview video. The screenshot half of this problem is already
solved well: `fastlane/Snapfile` drives `Modules/AppSnapshots` across two devices and two languages,
`Screenshots/verify_captures.py` refuses a capture set that does not match what was asked for, and
`.github/workflows/screenshots-record.yml` opens a pull request rather than pushing, because a
re-record changes what the store shows and deserves to be looked at like a change. This project is the
video that is missing beside it, and it is built to the same shape.

The valuable thing already in the repository is the fixture harness. `SnapshotTests.swift:19` launches
the app with `SNAPSHOT_MODE` set, which points it at the corpus in `Screenshots/` instead of a
server. The content is therefore deterministic, the same document is at the top of the list every
time (`openFeaturedDocument`, `SnapshotTests.swift:148`), and the labels follow the captured language
(`SnapshotLabels.current`). A preview video needs exactly those three properties. What it does not
need is the *shape* of those tests: each one relaunches the app and captures a single frame, whereas a
preview is one unbroken journey.

`ffmpeg` is not currently installed anywhere in the project.

## Decisions

**One video: 6.9" iPhone, en-US.** Apple allows three previews per localisation and the Snapfile
covers four screenshot sets, but a preview is choreography rather than a resize — the iPad flow puts
the document in a column beside the list and is a genuinely different edit, and a German run doubles
the review burden for a listing whose visitors mostly read the English one anyway. One video is also
the cheapest way to answer the open question below about whether Apple accepts simulator footage at
all. Locales and devices can be added later without redesigning anything: every piece below is
parameterised by device and locale already.

**The 6.9" slot is called `IPHONE_67`.** There is no `IPHONE_69` preview type. `spaceship`'s
enumeration stops at `IPHONE_67` and maps it to `[[886, 1920]]`
(`spaceship/lib/spaceship/connect_api/models/app_preview_set.rb:123`), which is what Apple's
specification lists for the 6.9" display. `deliver` infers the type by substring match on the
filename (`preview_type_from_filename`, same file line 143), so the string `IPHONE_67` must appear in
the name or the upload silently matches nothing.

**Crop, do not pad.** The simulator records the iPhone 17 Pro Max at its native 1320×2868, an aspect
of 0.4603. The required 886×1920 is 0.4615. Scaling to width 886 yields a height of 1926, six pixels
too tall. Three rows come off each end. Padding instead would put black bars down a store listing to
save six pixels of a status bar.

**A silent audio track is mandatory.** Apple's specification requires stereo audio, 256 kbps AAC at
44.1 or 48 kHz, with all tracks enabled. A simulator recording has no audio track at all, and a
preview without one is rejected. `anullsrc` supplies it.

**Markers, not guesses, delimit the recording.** `simctl io recordVideo` runs on the host; the
choreography runs in the simulator. The window between them has to be found rather than assumed. The
test logs a wall-clock timestamp when the first screen has settled and another when the last beat
ends; the simulator shares the host's clock, so subtracting the moment the recorder started gives
exact offsets. The alternative — polling for the app process and then trimming a fixed lead-in —
drifts with runner load, and a two-second drift opens the video mid-transition. Failing that, the
marker log also says *why* a run came out wrong, which a fixed offset never does.

**A run outside 15–30 seconds fails.** Truncating a slow run to fit would ship a story that stops
before the edit. The job stops instead, and the log carries the per-beat timings needed to retune the
marks.

**Its own lane, not an extension of `upload_screenshots`.** The Fastfile already keeps
`upload_metadata` and `upload_screenshots` apart so that one cannot disturb the other
(`Fastfile:29-31`). A preview upload gets the same treatment.

**Committed under `fastlane/app_previews/`, not under a top-level directory.** `Screenshots/Captures`
is committed and framed into the gitignored `fastlane/screenshots/` (`.gitignore:88`), because framing
is a real transform worth keeping separate from its input. Video has no framing step, so a second
location would be a copy for its own sake. `fastlane/app_previews/` sits beside the already-committed
`fastlane/metadata/` and is what `deliver` reads directly.

## Architecture

```
mise run preview:record
  │
  ├─ tuist generate
  ├─ xcodebuild build-for-testing        ← so the recorded run is short and predictable
  ├─ simctl boot + status_bar override   ← 9:41, full bars (the Snapfile does this for screenshots;
  │                                         a hand-rolled run must do it itself)
  ├─ simctl io recordVideo --mask ignored  ──┐ host clock noted at start
  ├─ xcodebuild test-without-building        │   -only-testing:AppSnapshots/AppPreviewTests
  │    └─ AppPreviewTests logs T_start, T_end│
  ├─ stop the recorder                     ──┘
  ├─ ffmpeg: trim [T_start, T_end] → conform
  └─ verify_preview.py                     ← refuses anything App Store Connect would refuse

mise run preview:upload  →  fastlane upload_previews  →  deliver(app_previews_path:)
```

## Changes

### `Modules/AppSnapshots/UITestNavigation.swift` (new)

The helpers currently `private` in `SnapshotTests.swift:134-170` — `launch`, `tapTab`,
`openDocuments`, `openFilter`, `openFeaturedDocument`, `labels`, `timeout` — lifted into a protocol
extension both test classes adopt. No behaviour changes; `SnapshotTests` keeps working exactly as it
does. `SnapshotHelper.swift` is untouched and `AppPreviewTests` does not use it: it never calls
`snapshot()`, and with one locale it asks `SnapshotLabels.current("en-US")` directly.

### `Modules/AppSnapshots/AppPreviewTests.swift` (new)

One method, `testRecordPreview`, running the approved beat sheet:

| Beat ends at | Beat | Waits for |
|----|------|-----------|
| 0:01 | Documents list, held | first cell |
| 0:06 | Filter button → sheet rises | title-and-content field |
| 0:08 | Type "Sonos" into the search field | — (field is already present) |
| 0:12 | Close sheet → list narrows | first cell |
| 0:17 | Tap first row → PDF renders | `otherElements["PDF"]` |
| 0:21 | Edit → sheet | "Edit document" static text |
| 0:24 | Hold on the edited document | — |

**The tag picker was replaced with a typed search mid-execution.** The beat sheet above originally
read "Tap Tag → picker → choose one" between the filter sheet and the narrowed list. Measured end to end it ran 35.7 seconds against the 30-second ceiling: the picker cost a
whole extra sheet round trip — open it, wait for it, tap a tag, wait for the sheet to close — that a
typed search does not. `SnapshotBootstrap.swift`'s fixture stub gained a `.titleContent` filter rule
for it: typing "Sonos" into the field the filter sheet is already built around matches two of the
eight fixture documents (Sonos Era 300, Sonos Sub), which narrows the list visibly without emptying
it, for the cost of one `typeText` in a sheet that was already open.

**Beats are scheduled against `T_start`, not chained.** Each beat waits for its element and then
sleeps until the elapsed time from `T_start` reaches its mark in the first column. This is the
difference between a video that is 27 seconds long and one that is 27 seconds *plus* however long six
screens took to settle — chained dwells would make the total a function of runner load, and with a
30-second ceiling that is a coin flip rather than a design. Scheduled beats put the whole cost of a
slow settle inside that beat's own slot: the video still ends at 0:24, that one beat is just held for
less time. A settle that overruns its slot entirely is logged with its overrun, which is the signal to
retune the marks.

27 seconds leaves three seconds of headroom under the ceiling and twelve over the floor, so a run has
to go badly wrong in a way worth failing over before it goes out of range.

The markers are printed, not attached: `print` from a test reaches the `xcodebuild` log, which the
script is already reading, whereas an `XCTAttachment` would mean parsing an `.xcresult` for two
numbers. Both are epoch seconds to millisecond precision, on a line prefixed `PREVIEW_MARKER` so the
script matches something that cannot collide with ordinary test output.

The list scroll uses `press(forDuration:thenDragTo:)` rather than `swipeUp`, which is too abrupt to
ship.

### `fastlane/Snapfile`

`skip_testing(["AppSnapshots/AppPreviewTests"])`. Without it every screenshot run executes the
preview choreography four times — twice per device, twice per language — producing nothing and
costing roughly two minutes each.

### `mise/tasks/preview/record` and `mise/tasks/ci/preview/record`

Mirrors the `screenshots:capture` / `ci:screenshots:capture` split: the same work, with the CI copy
existing so a workflow has one obvious entry point and the two can diverge without the local task
growing CI-only concerns.

The ffmpeg conform:

```
ffmpeg -ss "$start" -i raw.mov -t "$duration" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -vf "scale=886:-2,crop=886:1920" \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
  -r 30 -b:v 11M -maxrate 12M -bufsize 24M \
  -c:a aac -b:a 256k -ar 44100 -ac 2 \
  -movflags +faststart -shortest \
  fastlane/app_previews/en-US/01_IPHONE_67.mp4
```

886×1920 is 6720 macroblocks, inside Level 4.0's 8192, and its MaxMBPS allows 36 fps at that size, so
30 is within the level rather than merely close to it.

### `Screenshots/verify_preview.py` (new)

Reads the finished file with `ffprobe` and refuses it unless: the resolution is exactly 886×1920, the
duration is between 15 and 30 seconds, the frame rate is at most 30, the video is H.264 High at Level
4.0 or below, there is an enabled stereo audio track at 44.1 or 48 kHz, and the filename contains
`IPHONE_67`. This is the same instinct as `verify_captures.py` and `fastlane/metadata_lint.py`: the
published limits are stable, so a rejection belongs on a laptop rather than a day into review.

### `fastlane/Fastfile`

```ruby
lane :upload_previews do
  deliver(
    app_previews_path: APP_PREVIEWS,
    preview_frame_time_code: "00:00:14:00",
    overwrite_preview_videos: true,
    force: true,
    skip_binary_upload: true,
    skip_metadata: true,
    skip_screenshots: true,
    run_precheck_before_submit: false,
    precheck_include_in_app_purchases: false
  )
end
```

`force: true` skips the HTML preview, which otherwise waits for a keypress nobody is there to give,
and precheck is off for the same reason the other upload lanes leave it off — this touches no binary
and no text, so there is nothing for it to check.

`app_previews_path` being set is what triggers `Deliver::SyncAppPreviews` (`deliver/lib/deliver/runner.rb:170`).
The poster frame is set to 0:14, in the middle of the beat that holds the rendered PDF rather than at
its 0:17 boundary; Apple's 5-second default lands mid-transition while the filter sheet is rising.

### `.gitattributes`, `Brewfile`

`*.mp4 filter=lfs diff=lfs merge=lfs -text`, and `brew "ffmpeg"` beside the imagemagick that already
serves `screenshots:frame`.

### `.github/workflows/preview-record.yml` (new)

`workflow_dispatch` only, self-hosted macOS, `concurrency` queued rather than cancelled, opens a pull
request with the new `.mp4` and attaches it as a run artifact — the shape of
`screenshots-record.yml`, including its fallback when GitHub refuses to let Actions open a pull
request. The video cannot be embedded in the job summary the way the captures are; the artifact is
how it gets watched.

## Testing

The choreography is not unit-testable and asserting on it would be asserting on the app, which
`SnapshotTests` already declines to do for the same reason (`SnapshotTests.swift:10`). What is
testable is everything downstream:

- `verify_preview.py` gets tests over crafted fixtures: a file one pixel off, one 31 seconds long, one 14 seconds long, one
  with no audio track, one named without `IPHONE_67`. Each must be refused, and a conforming file
  accepted. These are the checks that stand between a green run and a rejection, so they are the ones
  worth testing.
- The marker parsing gets a test over a captured `xcodebuild` log, including the case where the
  markers are absent — a crashed test must fail the script rather than trim from zero.
- `mise run preview:record` end to end on a laptop is the acceptance test, and its output is the
  artifact under review.

## Out of scope

- The iPad and German previews. Parameterised for, not built.
- Framing the video in a device bezel. Apple's preview slot expects raw app footage.
- Any narration, music, or caption overlay.
- Wiring the upload into `release:submit`. It stays a deliberate, separate act until the first one has
  been accepted.

## Risks

**Apple may not accept simulator-captured footage.** The guidance leans toward previews captured on a
device, and simulator capture is widely used but nowhere promised. This is the one thing in the
project that cannot be settled before submitting. It is also cheap to find out, which is part of why
the matrix is one video: if it is refused, the loss is one choreography, and the recording step is the
only part that would need replacing — the conform, verify and upload stages are the same for footage
from a real device.

**`preview_frame_time_code` is only a request.** App Store Connect regenerates poster frames
server-side and has been known to ignore the requested timecode. If it does, the fallback is to pick a
beat that reads well at 5 seconds rather than fighting it.

**LFS weight.** `-b:v 11M -maxrate 12M` is a ceiling, not the average the encoder settles at: mostly
static UI over a fixed 27-second journey compresses well under it, and the committed file is 7 MB, not
the roughly 36 MB a naive bitrate × duration calculation suggests. Every re-record still adds another
copy that LFS keeps forever, just a cheaper one than expected. Two or three re-records are
unremarkable; a habit of re-recording weekly would not be.
