# Marketing screenshots

Replaces frameit with a renderer this repository owns, and splits the screenshot pipeline into three
stages that can be run independently.

Builds on the screenshot pipeline as it lands in #9, which has no design document of its own — this
is the first. The capture target, the fixtures, the corpus and the upload lane all stay. Only the
framing changes, and the stages around it are separated.

## Context

#9 produces 28 App Store screenshots — seven screens, two languages, two devices — by launching the
app on committed fixtures, driving it with XCUITest, and framing the result with fastlane's frameit.
The captures are sound. The framing is the weak half.

**frameit failed four times in one afternoon, and every failure was silent.**

| What happened | What it looked like |
|---|---|
| Output canvas takes its aspect from the background image | A 3000×4000 background produced 2151×2868 images that looked perfect and would have been refused on upload |
| Font paths resolve relative to the Framefile | An absolute `/System` path was read as a path inside the screenshots directory; every caption vanished, with no error saying so |
| Devices are identified by pixel dimensions, not by name | It knows neither the iPhone 17 nor the 13" iPad, so captures are renamed and resized to devices it does know |
| Its frame library lags Apple by about a year | Nothing to do but wait, or supply frames by hand |

Two of those produce a plausible-looking image that is wrong, which is the worst failure mode a
build step can have. None of them improve with time.

The second problem is speed. Framing is currently welded to capture: any change to a caption or a
layout means another hour of simulator time, because the captures are transient. That is the reason
the design has not been iterated on — not because nobody wanted to.

## Decisions

**Render the marketing image in SwiftUI.** The repository already renders SwiftUI to PNG in anger:
233 snapshot references are produced that way, with `SNAPSHOT_RECORD` gating whether a run writes
them. `ImageRenderer` at a stated size removes the canvas trap by construction, the app's own
`m3Primary` and SF Pro come for free, and the layout becomes snapshot-testable — a caption that
overflows fails a test rather than shipping.

**Commit the captures.** They are the expensive artefact: an hour of simulator time for 28 files of
roughly 700 KB. Everything downstream of them takes seconds. Committed, they turn framing into a
loop that can actually be iterated on, and they make corpus changes reviewable as image diffs rather
than as a description. They go through Git LFS, which `.gitattributes` already applies to `*.png`.

The cost, recorded so it is a choice rather than a surprise: each re-record stores 28 new LFS blobs.
Re-recording happens when the app's UI changes, which is rare, but a habit of re-recording casually
would consume LFS bandwidth.

**Three stages, three workflows.** Record, frame, upload — separated because they differ by three
orders of magnitude in cost and by audience. Frame is cheap enough to run on every pull request that
touches the layout or the captions.

**Dark treatment, no keyword.** Chosen from four candidates rendered from a real capture. The dark
ground is the app's own primary and gives the highest contrast against the App Store's white chrome.
Dropping the keyword removes a line of text that was competing with the headline; dropping the device
bezel returns roughly a fifth of the canvas height, which is what the document rows need to stay
legible at the thumbnail size where most people see a screenshot.

**German is Du.** Not a preference — the app already speaks Du in every string that addresses the
user (`Möchtest du wirklich "%@" löschen?`) and never Sie. The captions follow the product.

**iPad stays portrait and whole-screen.** Its list uses full-width rows, so three documents occupy
the top third and the rest is empty. Cropping to the content would fix the picture and misrepresent
the app. The real fix is multi-column iPad support, which is its own work; until then the iPad
screenshots show what the app actually does.

## Architecture

```
Record   XCUITest, ~1 hour     → Screenshots/Captures/<locale>/<device>-<screen>.png   committed
Frame    unit test, seconds    → fastlane/screenshots/<locale>/<name>_framed.png       generated
Upload   deliver, minutes      → App Store Connect
```

### `MarketingKit`

A framework holding one thing: the layout. A SwiftUI view taking a capture, a caption and a target
size, rendering the dark treatment. It depends on `Components` for the palette and on nothing else —
no fixtures, no API types, no test framework. Someone should be able to read this module and know
what a screenshot looks like without reading anything around it.

Captions live in a string catalog rather than in Swift, so translating one is a text edit and the
existing localisation tooling applies.

### `MarketingKitTests`

Two jobs that share a target because they share the view.

The first is ordinary snapshot tests: every caption, at both device sizes, in both languages — 28
assertions that catch overflow, clipping and contrast regressions in seconds and without a
simulator. This is the safety net frameit could not have.

The second is the render entry point: given the committed captures, write the framed images. Gated
by an environment variable, following `SNAPSHOT_RECORD` exactly, because that is the pattern this
repository already uses for a test that writes artefacts.

### `AppSnapshots`

Unchanged apart from where it writes. It captures into `Screenshots/Captures/` instead of handing
files to fastlane, and keeps its current assertions — a failure there still means a screen could not
be reached.

### fastlane

Keeps `snapshot` for the record stage, which loops devices and languages and overrides the status
bar, and `deliver` for upload. Everything else goes: `Framefile.json`, the generated backgrounds, the
font symlinks, the device rename, the iPad resize and both `keyword.strings`.

## Workflows

Three, each `workflow_dispatch`.

**Record** captures on both devices in both languages, then opens a pull request with the new images
on a branch of its own. It never pushes to `main`: a re-record is a visible change to what the store
will show, and it should be reviewed like one.

**Frame** renders the committed captures. It also runs automatically on pull requests that touch
`MarketingKit` or the captions, which is what makes copy changes reviewable.

**Upload** frames and then delivers. Manual, and gated on an input, because it rewrites the listing.

### Showing the images

Every workflow puts its images in the step summary, so a run can be judged without downloading
anything. A contact sheet — one image, the run's screenshots tiled and downscaled — plus a table of
what was produced.

**One mechanism needs verifying before it is relied on.** GitHub sanitises Markdown in step
summaries, and `data:` URIs in `<img>` are commonly stripped. If they render, a downscaled contact
sheet embeds directly. If they do not, the fallback is the artifact link plus the table, and for
Record — which commits its images — raw URLs on its own branch, which do render. This is settled by
one cheap run rather than by argument, and the plan schedules it early.

## Captions

| Screen | English | German |
|---|---|---|
| Inbox | Your inbox, everything just arrived | Dein Eingang, alles Neue auf einen Blick |
| Documents | Your whole archive, in your pocket | Dein ganzes Archiv in der Tasche |
| Search | Find any document in seconds | Finde jedes Dokument in Sekunden |
| Tags | Narrow it down by tag, type or date | Grenze nach Tag, Typ oder Datum ein |
| View | Read the whole document, right here | Lies das ganze Dokument, direkt hier |
| Edit | Fix a title or tag on the spot | Korrigiere Titel und Tags direkt |
| Settings | Your setup, under control | Deine Einstellungen, alles im Griff |

The English replaces copy with two grammar errors — *"criterias"*, *"quick and easy"* — and a habit of
describing the UI rather than what the reader gets. The German uses imperatives where the English
does, which reads better than the noun phrases it replaces.

## Sequence

1. `MarketingKit` with the layout and its snapshot tests. No pipeline changes; the tests are the
   proof.
2. The render entry point, and `AppSnapshots` writing to `Screenshots/Captures/`.
3. Commit the captures, delete frameit and everything that served it.
4. The three workflows, verifying the summary mechanism in the first run.

## Out of scope

- **iPad multi-column support**, and the better iPad screenshots that would follow it.
- **App preview videos.** Same capture problem, a different renderer.
- **More than two languages.** Adding one is a string catalog entry and a Snapfile line, but the
  copy has to be written by someone who speaks it.

## Risks

**Committed captures go stale.** Nothing detects that the app's UI has moved on while the images
have not. Mitigated by Record being one dispatch away, and by the images being visible in review.
Accepted rather than solved: a check would mean capturing to compare, which is the hour we are
avoiding.

**The layout is ours to maintain.** frameit's device frames come with Apple's, and drawing our own
means new devices need attention. Set against a frame library that already lags a year, this looks
like the better side of the trade.

**Snapshot tests of a marketing layout will be noisy under OS changes.** SF Pro's metrics move
between iOS versions, and every layout assertion sees it. The same is already true of the app's 233
references, so the repository has a way to deal with it.
