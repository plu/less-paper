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

## Claude uses the dev instance at `192.168.64.1:8000`, never Docker

**Never run `mise run docker:start`, `colima`, or any `docker`/`docker-compose` command.** Claude
works from a machine that cannot run them: it is itself an Apple Virtual Machine
(`kern.hv_support` is `0`), so colima's VM fails to boot with *"Virtualization is not available on
this hardware"*. There is no container runtime to reach, and no amount of retrying will produce one.

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

## App Store screenshots run on fixtures, never a server

`mise run screenshots:capture` drives the real app through the seven App Store screens on every
device and language Apple requires, then frames them. It needs no paperless instance: the app is
launched with `SNAPSHOT_MODE=true`, which swaps the API use cases for the payloads in
`Screenshots/Fixtures` and the thumbnails in `Screenshots/Thumbnails`.

Those fixtures are the raw API responses, downloaded once from a seeded instance by
`mise run screenshots:fixtures -- --url <instance>`. **Re-fetch them rather than editing them** —
they are the seed's output, and hand-edits are lost on the next fetch. Something the fixtures should
show but the seed does not is a change to `docker/seed/seed.json`, followed by a re-seed and a
re-fetch.

Both are read from the repository, not bundled, so nothing screenshot-shaped ships in a release
build. That limits screenshot mode to a simulator, which is where it runs.

What each language shows is curated in `SnapshotCorpus`: the German screenshots show German
paperwork — utility bills, a bank statement, a tax office — rather than the English documents behind
translated chrome. `SnapshotNames` renames tags, document types and storage paths to match.

Three things about frameit that are easy to lose an afternoon to, all handled in `fastlane/Fastfile`:

- **The output canvas takes its aspect ratio from the background image.** A background of the wrong
  shape silently produces an image App Store Connect rejects, and the image looks fine until it is
  refused. One background is generated per device size on every run.
- **Font paths in `Framefile.json` resolve relative to the Framefile**, so an absolute `/System`
  path is read as a path inside the screenshots directory and every caption is dropped without an
  error that says so.
- **The frame library lags the simulators.** Captures are renamed to the nearest frame with the same
  screen size before framing.
