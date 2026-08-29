# Conventions

Instructions for any AI agent working in this repository.

## Comment Style

**Never write `///` doc comments. Never write `/** ... */` doc comments. Only ever `//`.**

This applies everywhere — types, properties, methods, initialisers, test helpers. No exceptions,
including when adding to a file that still contains old-style doc comments.

Comment only when something is **exceptional** — when a future reader would otherwise stop and
wonder why the code is the way it is. A comment earns its place by explaining a non-obvious
constraint, a subtle trap, or a decision that looks wrong until you know the reason.

```swift
// Reading state at delivery rather than capturing it: a keystroke would otherwise report a
// search type the user has since changed.
case .searchDebounced:
    return .runFilterUpdated(state)
```

Do **not** restate what the code already says:

```swift
// Wrong — adds nothing.
/// The current sort direction
private let direction: SortDirection
```

## `@ViewAction` views send with `send`, never `store.send`

In a view annotated `@ViewAction(for:)`, the macro generates a `send` that wraps the action in
`.view(…)`. Calling `store.send` there compiles but emits:

> Do not use 'store.send' directly when using '@ViewAction'

It applies to `task` and other modifiers too, not just button actions — the trailing `.finish()`
works the same either way:

```swift
// Wrong — warns.
.task { await store.send(.view(.onAppear)).finish() }

// Right.
.task { await send(.onAppear).finish() }
```

Views without the macro — `DocumentBulkEditGenericValueView` is one, because it is generic — keep
using `store.send(.view(…))`. Check for the annotation before copying a line between views.

Builds are not warning-free by default, so a new warning is easy to miss. When touching a view,
skim the build output for its file.

## Confirmations use `ConfirmationPopupView`, never the system dialog

**Never use `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`.** Every confirmation in
this app goes through `PopupPresenter` and `ConfirmationPopupView`.

The system dialog is not just off-brand — inside a presented sheet it renders as a clipped popover
anchored to the wrong edge, and the cancel button can be pushed off screen entirely. The custom
popup is presented by `PopupPresenter` above everything and is unaffected.

The shape is a `@DependencyClient` presenter that returns whether the user confirmed, with the
reducer awaiting it inside an effect. `DocumentDeleteConfirmationPresenter` and
`DocumentNoteDeleteConfirmationPresenter` are the two to copy:

```swift
// Wrong — off-brand, and clipped inside a sheet.
state.destination = .confirmation(.confirmDelete(name: state.tag.name))

// Right.
return .runConfirmDelete(noteId: noteId)
```

```swift
static func runConfirmDelete(noteId: Note.Id) -> Self {
    @Dependency(\.documentNoteDeleteConfirmation.present)
    var presentConfirmation

    return .run { send in
        guard await presentConfirmation() else {
            return
        }
        await send(.deleteConfirmed(noteId))
    }
    .cancellable(id: CancelID.confirmDelete)
}
```

For the common case — deleting a named record — there is one shared presenter already:
`Components/Popup/DeleteConfirmationPresenter.swift`. It takes the entity title and the record's
name and renders `Delete tag` over `Do you really want to delete "Inbox"?`:

```swift
@Dependency(\.deleteConfirmation.present)
var presentConfirmation

guard await presentConfirmation(.deleteTag, name) else {
    return
}
```

Reach for that first. Write a presenter of your own only when the popup needs custom content, as
`DocumentBulkEditConfirmationPresenter` does.

## Every module owns its strings

Each framework module carries its own `Modules/<Name>/Resources/Localizable.xcstrings`. **There is
no shared catalogue.** A new user-facing string goes into the catalogue of the module that displays
it, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically.

One catalogue used to be globbed into all ~30 framework targets, which made every new string dirty
every target: a PR touching one module took 222s, the same PR plus one string took 1711s. The split
is what removed that, and anything that reintroduces a shared catalogue brings the 1711s back.

**A module can only use the strings in its own catalogue.** `STRING_CATALOG_GENERATE_SYMBOLS`
emits `LocalizedStringResource.cancel` as `internal` to whichever target compiles the catalogue, so
no symbol crosses a module boundary. Two modules that both show *Cancel* each get their own `cancel`
key — **the duplication is the design, not an oversight.** It measures 1.30x across the project,
and it is what buys back the rebuild time without giving up symbol generation.

The compiler catches a string you have not added, but says it two different ways:

```
// No other module defines it.
error: type 'LocalizedStringResource' has no member 'save'

// Another module does define it — same problem, different message.
error: 'import' is inaccessible due to 'internal' protection level
```

Both mean: add the key to *this* module's catalogue. Copy the entry verbatim from whichever module
already has it, translation included, so the two do not drift.

Three more things worth knowing:

- **The catalogue reaches the target through the buildable folder, not a `resources:` glob.**
  `Module+Targets.swift` sets `resources` only for `.app`; frameworks pick the file up because
  `Modules/<Name>` is a synchronized folder. Creating the file is the whole job — no manifest edit.
- **Modules with no user-facing text have no catalogue at all** — `ApiImplementation`,
  `ImageFeature`, `Logging`, `SnapshotSupport` and the test-support modules. Do not add an empty one
  for symmetry; that puts the module back on the rebuild path for every string change.
- **The symbol is derived from the key, not equal to it.** `asnType.equals` becomes
  `.asnTypeEquals`, and a key that collides with a keyword is declared backticked (`` `import` ``)
  while the call site stays `Text(.import)`. Anything grepping for usages has to account for both,
  and for `Label(.edit, systemImage:)` — a resource in first position, which is what an earlier
  audit missed when it wrongly concluded `edit` and `Tag` were dead.

**`@testable import` re-exposes those internal symbols**, so a test target that `@testable import`s
two modules which both define `cancel` gets an ambiguity error rather than a missing-member one.
Every test module imports exactly one product module today except `ApiImplementationTests` and
`DocumentsFeatureTests`, and neither of those uses a string symbol. Keep it that way; if a test
needs one, reach for it through the single module under test.

Finally, a log line to ignore. Any build that compiles more than one catalogue prints, once or
twice per catalogue-owning target:

```
Internal Error: DecodingError.dataCorrupted: Data was corrupted. Debug description: Corrupted JSON. Underlying error: unexpected end of file
```

It is **not** a broken catalogue and it fails nothing. It appeared with the split, so it is new, but
it was chased down: `xcstringstool compile` and `generate-symbols` both exit 0 on every catalogue,
a single-catalogue build (`Components` alone) prints it zero times, and the built framework carries
the full key set — `ServersFeature.framework` ships all 23 keys in both `en.lproj` and `de.lproj`
with the right German values. It is Xcode's build system logging against itself when several
`CompileXCStrings` tasks run in parallel. Don't spend an afternoon on it.

## UI tests never mutate global server state

UI tests live in `AppUITests` and drive the real app against paperless-ngx. Each test creates its own
Paperless user, so every tag, correspondent, document type, storage path and saved view it creates is
owned by that user and invisible to every other test. The list a test opens starts empty.

`ShareApp` is the only harness app left, and it is permanent — it stands in for the share extension,
which XCUITest can otherwise reach only through another app's share sheet. **Do not add another
harness app.** A new feature gets a journey here instead.

**Never write a helper that deletes all of something.** `deleteAllTags()` and its kind are why the
old per-feature harness suites could not run in parallel, and they are gone.

Two exceptions, both probed against paperless-ngx 3.0.5:

- **Custom fields have no owner** and are global — every user sees every custom field. Namespace
  them by name (`uit-<id>-<label>`) and never assert on the total count of the custom field list.
- **Documents consumed from `docker/consume/` have no owner** and form a shared read-only corpus.
  Read from it freely; a test that needs to *modify* a document must upload its own first, with
  `Fixtures.uploadDocument(titled:token:)`. Pass the **test user's** token, never admin's: paperless
  owns a document to whoever created it, so an admin-owned document is invisible to the user the
  journey runs as. Delete it in `tearDown` — deleting the user does not cascade to its objects.

One trap that is not about ownership: **never delete the seeded server in a journey.** It is the
server the app is running on, so removing it logs the app out mid-test. A journey that needs to
exercise deletion adds a second server and deletes that one.

Tests always launch with a `UITestConfiguration`, even the onboarding journey that starts without a
server. Launching with no configuration at all would let the app read whatever `servers.json` the
simulator happens to hold, which is how a developer machine and a clean CI runner end up
disagreeing.

## Claude uses the dev instance at `192.168.64.1:8000`, and Docker only through the host

**Never run `mise run docker:start` or `colima` here.** Claude works from an Apple Virtual Machine
(`hw.model` is `VirtualMac2,1`, `kern.hv_support` is `0`), so colima's own VM cannot boot: *"Virtualization
is not available on this hardware"*. That has not changed and will not.

**`docker` itself can work, when the host forwards its socket in.** The host runs colima; forwarding
its socket over SSH gives this VM a working Docker CLI with no runtime of its own:

```bash
# On the host, once per session. -R, not -L: the socket is bound on the remote side, which is here.
ssh -fN -R /Users/admin/docker-host.sock:/Users/plu/.colima/default/docker.sock admin@<vm-ip>

# Here
export DOCKER_HOST=unix:///Users/admin/docker-host.sock
```

`sshd` refuses to bind over an existing file and `StreamLocalBindUnlink` is off by default, so a
dropped connection leaves a stale socket that makes the next attempt fail with *"cannot bind"*.
Delete it and reconnect.

**Containers started this way run on the host, not in this sandbox.** They share the host's ports,
disk and colima state — including the two paperless stacks that are always up:

| Project | Port | What it is |
|---|---|---|
| `paperless-dev` | 8000 | the instance every local test targets |
| `paperless-ci` | 9000 | what CI targets |

Both are someone else's working environment. Use a distinct `-p` project name, pick a port that is
free (8000, 8010, 9000 and 9010 are taken), and do not restart or remove a container you did not
create without saying so first.

Use the **dev instance running on the host** instead, at `http://192.168.64.1:8000` —
`192.168.64.1` is the host as seen from inside the VM, and `localhost` is not. Point the tests at it
by exporting `TUIST_PAPERLESS_TEST_URL`, which `Module+InfoPlists.swift` bakes into every bundle's
`PAPERLESS_TEST_URL` key, where `URL.testValue()` reads it. It otherwise defaults to the
`paperless-ci` instance at `http://localhost:9000`, and every test fails on a connection refused:

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
```

It is read at **generate** time, not at run time, so a `tuist test` after a generate that did not
carry the variable still targets port 9000. Export it for both.

This overrides the usual rule that verification runs against `paperless-ci` on port 9000: that
instance only exists where Docker does. Tests still create and delete their own users, so they are
as safe against the dev instance as against the CI one — but its data is real, so the "never mutate
global server state" rule above matters more here, not less.

## `gh` and `git push` authenticate through fnox

There is no `gh auth login` credential store on this machine and no git credential helper. Both
tools authenticate with `GH_TOKEN`, a fine-grained PAT kept in the **global** fnox config at
`~/.config/fnox/config.toml` — not in this repo's `fnox.toml`. The token is scoped to
`plu/less-paper` alone (contents, issues and pull requests read-write; actions and checks read), so
anything outside this repository — or an edit to a workflow file — comes back `403`.

`~/.zshrc` runs `eval "$(fnox activate zsh)"`, which is why `gh` just works in a terminal. **An
agent's shell is not interactive, so that line never runs and `GH_TOKEN` is unset.** Wrap the call:

```bash
mise exec -- fnox exec -- gh pr create …
```

`fnox` itself is not on `PATH` without `mise exec --`.

`git push` needs more than the variable — git does not read `GH_TOKEN`, so it prompts for a
username and hangs until it times out into GitHub's device flow. Hand it a credential helper for
the single command:

```bash
GIT_TERMINAL_PROMPT=0 mise exec -- fnox exec -- git \
  -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' \
  push -u origin <branch>
```

`GIT_TERMINAL_PROMPT=0` turns a credential failure into an immediate error instead of a hang.

When every call starts returning `403`, the PAT has expired. Re-mint it at
<https://github.com/settings/personal-access-tokens> and store it with
`cd ~ && fnox set --global GH_TOKEN`.

## A pull request title is a commit message

**Every PR title takes a Conventional Commits prefix** — `feat:`, `fix:`, `docs:`, `chore:`,
`refactor:` — in the same voice as the commits inside it.

This is not tidiness. Pull requests here are **squash merged**, so the PR title *becomes* the commit
message on `main`, permanently, with the number appended. `git log origin/main` is a list of PR
titles:

```
feat: a tip jar in Settings (#28)
feat: open a document from a lesspaper:// link (#27)
chore: bump jdx/mise-action to v4 (#26)
```

Write the title as the line you want in that log, not as a headline for the PR page. A title that
reads well on GitHub and badly in `git log` is the wrong way round: the page is temporary and the
log is forever.

**One title in that history is already wrong** — `Give every module its own string catalogue (#29)`
— because it was written as a headline. It cannot be fixed now without rewriting `main`, which is
why it is worth getting right the first time rather than at review.

The prefix should match what the change is, not which branch it came from: a branch named
`chore/…` holding a user-visible fix still gets `fix:`.

## The App Store listing lives in `fastlane/metadata`

Downloaded from App Store Connect, committed, and uploaded by `deliver`, so changing a description
is a diff someone can review rather than a form with no history.

| Task | Does |
|---|---|
| `mise run metadata:lint` | checks every field against Apple's published limits — no API call |
| `mise run metadata:download` | overwrites the local files with what the store currently shows |
| `mise run metadata:upload` | rewrites the listing text; screenshots and binary untouched |

**`fnox set KEY -d "description"` with piped stdin silently discards the value.** It stores the
description, prints `✓ Set secret`, and leaves the entry with no `value` field — after which
`fnox get` returns nothing. Set the value first, and add a description separately if one is wanted.

**A missing secret is not an error to `fnox get`.** It exits `0`, prints nothing, and warns on
stderr, so anything checking only the exit code will happily write an empty file.

Three things that cost time to work out, all of which fail quietly:

- **`download_metadata` needs `--force`.** It calls `UI.confirm` before overwriting local files, and
  a non-interactive shell never answers — so it exits `0` having written nothing, which looks exactly
  like an app with no metadata.
- **`deliver`'s `verify_only` cannot check metadata on its own.** It hashes a binary, so without one
  it dies with `no implicit conversion of nil into String`. `metadata:lint` exists because of this.
- **`review_information` is gitignored and comes from fnox.** It holds a demo account password, a
  phone number and an email address, and this repository is public. The seven `ASC_REVIEW_*` secrets
  are written into those files by `mise run metadata:review-info`, which `metadata:upload` runs
  first — so an upload carries the contact details without them ever being committed. Setting some
  and not others is an error rather than a half-filled contact card; setting none is fine, and
  `deliver` then leaves that section of the listing alone.

## Errors go to a local log the user can share

`Logging` holds a `LogClient` dependency over a `LogWriter` actor; `DiagnosticsFeature` is the screen
in Settings that reads, shares and clears it. Nothing leaves the device unless someone taps share.

| Task | Does |
|---|---|
| `log.error(_:category:)` | records, from any feature |
| Settings → Diagnostics | read, share via `ShareLink`, clear behind a confirmation |

- **`os_log` is not the shareable record, and could not be.** `OSLogStore.local()` is unavailable on
  iOS — the compiler rejects it — so the only scope an app can open is `.currentProcessIdentifier`,
  which reads the current process and nothing else. A relaunch leaves an empty log, and a relaunch is
  what people do after the app misbehaves. Every line still goes to `os_log` for Xcode and Console;
  the file is what gets shared.
- **Bodies are never written.** One line per API request — method, redacted path, status, response
  size — plus errors and warnings. `LogRedaction` strips credential-shaped query values and never
  writes a header value. Its tests are the ones that matter: a denylist with no test is a rule that
  silently stops working.
- **The file is capped at 1 MB with one rotation**, checked on write rather than on a timer, and it
  lives in caches so the system can reclaim it. Diagnostics must never be why a document cannot be
  saved.

## Recording a snapshot reference means editing the scheme

References live under `Snapshots/`, and `SNAPSHOT_RECORD` decides whether a run writes them. The
variable is declared in `Tuist/ProjectDescriptionHelpers/Extensions/Dictionary+Extensions.swift`
with `isEnabled: false`.

**Passing it on the command line does not work.** Neither `SNAPSHOT_RECORD=all tuist test` nor
xcodebuild's `TEST_RUNNER_SNAPSHOT_RECORD=all` reaches the test process, and the run then passes
having recorded nothing — which reads exactly like success. To re-record: flip `isEnabled` to
`true`, `tuist generate`, run the tests, flip it back, and regenerate. Never leave it enabled.

A test with **no** reference yet is a different case: swift-snapshot-testing writes one on the first
run and fails, and the second run passes against it. Nothing had to be enabled, so nothing warns
you — **look at what was recorded before trusting it**. A reference records whatever the code
produced, bug included; that is how 14 German references were recorded showing English captions.

## App Store screenshots run on fixtures, never a server

The pipeline is three stages, separated because they differ by three orders of magnitude in cost:

| Stage | Command | Cost | Output |
|---|---|---|---|
| Record | `mise run screenshots:capture` | ~1 hour | `Screenshots/Captures/` — **committed** |
| Frame | `mise run screenshots:frame` | ~5 seconds | `fastlane/screenshots/` — generated |
| Upload | `mise run ci:screenshots:upload` | minutes | App Store Connect |

Each has a manual GitHub Action of its own, and Frame also runs on any pull request touching
`Modules/MarketingKit`, the captures or the string catalog.

**The captures are committed, so changing a caption costs seconds rather than an hour.** They are
the expensive artefact and everything downstream of them is cheap. The cost of that choice: each
re-record stores 28 new LFS blobs, so re-record when the app's UI has moved, not out of habit.

Record drives the real app through the seven App Store screens on every device and language Apple
requires. It needs no paperless instance: the app is launched with `SNAPSHOT_MODE=true`, which swaps
the API use cases for the payloads in `Screenshots/Fixtures` and the thumbnails in
`Screenshots/Thumbnails`.

Those fixtures are the raw API responses, downloaded once from a seeded instance by
`mise run screenshots:fixtures -- --url <instance>`. **Re-fetch them rather than editing them** —
they are the seed's output, and hand-edits are lost on the next fetch. Something the fixtures should
show but the seed does not is a change to `docker/seed/seed.json`, followed by a re-seed and a
re-fetch.

Both are read from the repository, not bundled, so nothing screenshot-shaped ships in a release
build. That limits screenshot mode to a simulator, which is where it runs.

Both languages show the same documents, curated in `SnapshotCorpus` — the eight with a real PDF in
`docker/data`. The seed's German paperwork is generated filler, whose thumbnails photograph as a
blank sheet. `SnapshotNames` translates the tags, document types and storage paths instead, so the
German screenshots read Möbel and Aufbauanleitung over the same manuals.

`SnapshotCorpus` also decides which thumbnails are worth keeping: `fetch_fixtures.py` downloads only
the documents it names, and clears the directory first.

Uploading is gated behind an `upload` input that defaults to false, because it rewrites what the App
Store shows. It sends **screenshots and nothing else** — the binary still ships through `altool` in
`mise/tasks/ci/upload`, so the two cannot race. Record likewise never pushes to `main`: it opens a
pull request, so a change to what the store will show gets reviewed like any other.

Framing is `MarketingKit`, a SwiftUI view rendered with `ImageRenderer` at a stated size. It
replaced fastlane's frameit, which silently produced plausible images of the wrong size. Two things
to know about it:

- **The caption is resolved eagerly to a `String` with a locale the caller states.**
  `Text(LocalizedStringResource)` resolves through the environment's locale, so a resource carrying
  its own locale is ignored — and one render loop writing both languages then puts English captions
  on the German screenshots. It shipped that way once.
- **The render is asked for with a `.marketing-render` marker file, not an environment variable.**
  `TEST_RUNNER_`-prefixed variables do not reach the test process here, for the same reason
  re-recording a snapshot means editing the scheme (above). `mise run screenshots:frame` writes the marker and removes it again.

The README shows `docs/images/screenshots.png`, a strip of four English iPhone screens rebuilt by
`mise run screenshots:readme` after a re-frame. It is the one committed PNG kept **out** of LFS, so
that it renders wherever the README is read.

`Screenshots/contact_sheet.py` tiles a directory of screenshots into one image for a workflow's step
summary. It needs Homebrew's ImageMagick (`brew install imagemagick`), which is not a mise tool
because the only backends for it build from source.
