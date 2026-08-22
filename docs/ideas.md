# Ideas

Good-to-implement ideas surfaced while working on something else and deliberately left out of
scope at the time. Not a commitment and not prioritised — a place to park things so they are not
rediscovered from scratch.

When picking one up, move it out of here and into a `docs/plans/` document.

---

## Discover documents that *start* matching a tab's filter

Cross-tab sync propagates document content but deliberately never changes a list's membership.
An edit that makes a document newly match the other tab's filter cannot be detected locally — the
other tab only learns about it on its next fetch.

Closing this needs either a client-side filter-rule evaluator (large, and it still cannot invent
documents the client has never loaded) or a re-fetch of the other tab. Both were rejected as
disproportionate at the time.

Surfaced during: `docs/plans/2026-08-12-cross-tab-document-sync.md`.

---

## Refresh lists after an import

Creating a document does not refresh either document list. The new document appears only after a
manual pull-to-refresh or the next `onAppear` with an empty list.

This is not only the share extension: the in-app import and scan buttons run the same
`ShareFormReducer` path, and `DocumentListReducer` ignores every `documentImport` action
(they fall into the `case .binding, .delegate, .destination, .documentImport, …: return .none`
catch-all). So even an import started from the list that is on screen leaves that list unchanged.

The *badge* is no longer affected — `CreateDocumentUseCase` refreshes statistics as of #131 — so
what remains is list membership. From the share extension it is harder than it looks: that is a
separate process, so it cannot send an action into the app's store. It would need the app to notice
on its next foreground, which is a trigger #131 added for statistics and could reuse.

Surfaced during: `docs/plans/2026-08-12-cross-tab-document-sync.md`, re-verified 2026-08-15.

---

## Surface the server-side trash

Paperless-ngx moves deleted documents to a trash rather than destroying them, and exposes it over
the API. The app deletes but never shows the trash, so a mistaken delete can only be undone from the
web UI.

Would need a list screen plus restore and empty-trash actions. Worth pairing with an undo affordance
on the delete itself, which today is a confirmation popup and nothing more.

Surfaced during: `docs/plans/2026-08-14-delete-document.md`.

---

## `appStorage` does not use the app group

The file-backed shared keys write into `.applicationGroupDirectory`, so the app and the share
extension see the same data. The `appStorage` ones do not — nothing sets `defaultAppStorage`, so
each process reads its own `UserDefaults.standard`. `inboxDocumentCount` is the only key affected
today.

Currently latent rather than broken: nothing in the share extension writes that count. It becomes a
real bug the moment the extension refreshes statistics — which is exactly what the import-refresh
idea above would do.

Fixing it means pointing `defaultAppStorage` at the group suite in both targets, and deciding
whether to migrate the existing values or let them re-read as 0 on the next refresh.

Surfaced during: `docs/plans/2026-08-14-delete-document.md` and the #131 inbox count work.

---

## One string catalog invalidates every module

`Module+Targets.swift` gives every `.framework`/`.staticFramework` target
`Shared/Framework/Resources/**` as a resource, so all ~30 of them embed the single
`Localizable.xcstrings`. Changing one string changes every module's fingerprint, and Tuist's
selective testing correctly concludes that everything changed.

Measured on three runs from the same day:

| Branch | Touched | Duration |
|---|---|---|
| `ideas_cleanup` | docs only | 23s |
| `fix_unresolved_filter_ids` | `DocumentsFeature` only | 222s |
| `fix_has_any_tag` | `DocumentsFeature` + one string | 1711s |

Since most feature PRs add a string, most PRs take the slow path.

The obvious cheap fix does not work: moving the catalog into one shared module changes nothing,
because every module would then depend on that module and the fan-out is identical. It has to
actually split. Of 170 keys, **110 (64%) were used by exactly one module**, so per-module catalogs
would not duplicate much — but the 56 genuinely shared ones (`cancel`, `close`, `save`, `name`,
`title`, `url`, `tags`, `deleteConfirmation`, …) need a home.

That split was measured when the catalog held 170 keys; it now holds 206, so the proportions need
re-deriving before they are quoted at anyone.

The catch is why the current design exists at all: there are no hand-written
`LocalizedStringResource` extensions and Tuist's synthesizers are off, so `.cancel` comes from
Xcode's built-in string catalog symbol generation — and those symbols are `internal` to whichever
target compiles the catalog. Attaching the catalog everywhere is *how* every module can say
`.cancel`. Sharing a subset means hand-written `public` accessors for those 56 keys, losing
auto-generation for exactly the strings a translator is most likely to touch.

Worth re-measuring first: #139 stopped the XCUITest targets running on every PR, which should take
a lot out of the slow path. If a string-change run lands somewhere tolerable, this may not be worth
its cost.

Surfaced during: the CI runtime investigation, 2026-08-15.

---

## Two unmeasured CI leads

From the same investigation, both plausible and neither timed:

- `ci:test` passes `--clean` to `tuist test`. `ci:clean` already runs
  `git clean -ffdx && git reset --hard`, so the workspace is pristine; `--clean` additionally
  discards derived data on a runner where it would otherwise persist.
- `ci:cache` runs `tuist cache --external-only`, so internal modules never come from the binary
  cache and are compiled from source every run.

Surfaced during: the CI runtime investigation, 2026-08-15.

---

## Small localization loose ends

Two things noticed while working on the tag filter, neither urgent:

- The tag rule picker reads **All | Any | Assigned | Not assigned** in English but
  **Alle | Alle | Zugewiesen | Nicht zugewiesen** in German, because `any` is translated `"Alle"`,
  identical to `all`. It predates the fourth segment added in #133, and the string also drives the
  correspondent, document type and storage path fields, so it was left alone rather than changed
  underneath them.
- Four keys have no detected usage and may be dead: `edit`, `makeDefault`,
  `SavedViewsFeature_formHasFieldErrors`, `Tag`. Detection accounted for Xcode's key→symbol
  transform (`asnType.equals` → `asnTypeEquals`), so these are more likely genuine than the rest,
  but worth confirming by hand before deleting.

Surfaced during: #133 and the string catalog analysis.

---

## Remember the last bulk-rename template

`DocumentBulkEditTitleReducer.State.template` opens on `{title}` every time — a no-op the user
extends, rather than the blank it originally started as. What it still does not do is remember the
template you used last time, so `{created_year}-{correspondent}` gets retyped for every batch. An
`@Shared(.appStorage)` key per server would cover it, but note the caveat already recorded under
"`appStorage` does not use the app group".

Surfaced during: `docs/plans/2026-08-16-bulk-edit-title.md`.

---

## The bottom toolbar is full

Five icons plus the overflow menu is the maximum: measured on an iPhone 17 Pro (402pt), six span
411pt and clip at both ends. "Edit title" went into the overflow menu for that reason alone, which
makes it much harder to discover than the four edit actions beside it.

Anything else that wants a place there needs the row to change shape first — a scrolling row, a
second line, or grouping the four edit actions behind one "Edit" menu.

Surfaced during: `docs/plans/2026-08-16-bulk-edit-title.md`.

---

## The list's status capsule can cover the last row

`DocumentListView` and `InboxView` both attach `DocumentListStatusBarView` with
`.overlay(alignment: .bottom)`. An overlay floats the capsule without reserving room for it, so the
last row of the list sits underneath it with no way to scroll clear.

This is the same defect the filter sheet's match-count capsule had, where it was fixed by attaching
with `.safeAreaInset(edge: .bottom, spacing: .x0)` instead — which floats identically *and* insets
the scrollable content by the capsule's height. The list was left alone at the time to keep that
change to one screen.

Less acute here than it was in the sheet: a list scrolls freely, so the obscured row can be brought
up by scrolling further, whereas the sheet's compressed content had nowhere to go. Still wrong.

Surfaced during: `docs/plans/2026-08-16-filter-match-count.md`.

---

## A first-run message for an empty archive

`DocumentListEmptyView` now says something specific for an error, an inbox with no inbox tag, an
empty inbox and a filter that matches nothing. The fifth case — a genuinely empty archive —
still reads "No documents found".

For a new user who has uploaded nothing that is an onboarding moment, not a failure, and it wants
copy that belongs with a wider first-run story rather than a lone string swap.

Surfaced during: `docs/plans/2026-08-16-document-list-empty-states.md`.

---

## Why does the teardown binding write only warn on some sheets?

A SwiftUI `TextField` writes back through its binding once as its view tears down. In the filter
sheet that write landed *after* `destination = nil` and produced a ComposableArchitecture runtime
issue, fixed by dropping writes that carry the value the store already holds.

`ServerFormView`'s header fields have the identical shape — a manual `Binding(get:set:)` whose
setter sends unconditionally, on a view presented as a `@Presents` destination — and instrumenting
it shows the teardown write happening with an identical value. But **no runtime issue follows**, on
either dismissal path.

So those two ingredients are necessary and not sufficient: something makes the write land before
`destination = nil` in one sheet and after it in the other. Worth understanding, because until it is
understood there is no way to tell which of the app's other sheets are exposed without driving each
one by hand.

Surfaced during: #147, verified by instrumentation on 2026-08-16.

---

## The `ci` docker instance has drifted from the seed

`mise run docker:start` brings up two paperless instances: `dev` on port 8000 and `ci` on port 9000.
The XCUITest harness apps talk to `ci` (`PAPERLESS_TEST_URL` defaults to `http://localhost:9000`).

Measured 2026-08-16, `ci` no longer matches `docker/seed/seed.json`:

- 14 of the 25 seeded documents are present; 12 are missing
- **none** of them carry a correspondent, document type, storage path, tag or ASN
- two documents are both titled "TonieBox"

`dev` is fine. This matters because `seed.py` keys documents **by title**, so a duplicate title
makes the seed ambiguous, and any XCUITest asserting on metadata is asserting against a fixture
that no longer has any. `python3 docker/seed/seed.py --url http://localhost:9000 --verify` reports
the drift in full.

Whether the fix is re-seeding `ci`, or making the harness apps point at `dev`, or teaching `seed.py`
to reconcile rather than assume, is the open question.

Surfaced during: the bulk edit title end-to-end verification, 2026-08-16.

---

## `testCreate` fails as the first XCUITest of a cold run

Observed on three of the six app-test targets on 2026-08-22 — `TagsApp`, `DocumentTypesApp`,
`SavedViewsApp` — always with the same shape:

```
Failed to tap "Add tag" Button: No matches found for first query match sequence:
`Descendants matching type Button` -> `Elements matching predicate '"Add tag" IN identifiers'`
```

Every one of them passes when re-run alone with
`-only-testing:TagsAppTests/TagsAppTests/testCreate`, and `CorrespondentsApp` and `StoragePathsApp`
never failed at all. `testCreate` is alphabetically first, so it is the test that absorbs the very
first `app.launch()` of a run — the toolbar button is queried before the list has finished its
first layout.

Unrelated to what the test asserts: `testCreate` runs with the list emptied, so no row view is even
instantiated. A `waitForExistence` on the button before tapping would likely settle it, but the
right fix may be in `UITestSupport` so every target gets it at once.

Surfaced during: `docs/plans/2026-08-22-confirmation-popup-migration.md`, 2026-08-22.

---

## `ServerRowReducerTests` cannot be run on its own

```
tuist test ServersFeature --no-selective-testing -- -only-testing:ServersFeatureTests/ServerRowReducerTests
```

fails `test_view_serverTapped_fillsCachesBeforeSelecting` with an issue recorded at
swift-dependencies' `TimeZone.swift:22` — the "blank TimeZone dependency" report. The full
`ServersFeature` suite passes, so CI is green and has always been green.

The suite is declared as a bare `@Suite` with no `.dependencies()` trait, unlike e.g.
`SavedViewRowViewTests`, so it is relying on some other suite in the same bundle having established
`\.timeZone` before it runs. That coupling is invisible until the suite is run alone.

Reproduced on unmodified `main` as well as on the migration branch, so it predates both. Worth
auditing which other suites are bare `@Suite` and depending on a neighbour for their dependencies.

Surfaced during: `docs/plans/2026-08-22-confirmation-popup-migration.md`, 2026-08-22.

---

## The list's action menu is already A–Z — so check what was actually seen

Recorded because it was reported as needing sorting, and does not: `defaultActionsMenu` in
`DocumentListTopTrailingToolbar` declares **Import, Scan, Select, Servers ▸**, which is A–Z in
source order. It survives translation too — German is Importieren, Scannen, Selektieren, Server,
alphabetical by coincidence of `Sel` < `Ser`. `selectActionsMenu` (Select all loaded, Select all
matching, Select none) is likewise already sorted.

So if a menu genuinely looked unsorted, it was one of these instead:

- **The bulk-edit overflow menu** in `DocumentListBottomToolbar`: Edit title, Merge documents,
  `Divider`, Delete documents. Not A–Z, and deliberately so — there is a comment explaining that
  Delete sits behind the divider rather than one mistap from four reversible actions. Sorting it
  would put Delete first, which is exactly what that comment exists to prevent.
- **The saved-views menu** in `DocumentListTopLeadingToolbar`: All documents, `Divider`, then the
  server's saved views in server order. Semantic, not alphabetical.

There is also a rendering wrinkle worth confirming before anyone sorts anything by eye: UIKit
orders menu elements from the anchor outwards, so a menu opened from a control near the **bottom**
of the screen renders bottom-up — the first-declared item appears last. The bulk-edit overflow menu
is anchored in the bottom toolbar and so is a candidate. If that is what happened, source order was
never the problem and sorting it would make the rendered order worse.

Note that #173 sorted the document *action* menus by source order, which is A–Z in **English
only** — the labels are localised, so the row's reversible actions read Edit, Preview, Share, View
in English and Bearbeiten, Vorschau, Teilen, Anzeigen in German, which is not alphabetical at all.
Genuinely locale-correct sorting means rebuilding each menu as data and sorting on the resolved
label at render time, which is a change of shape, not of order.

#173 also settled the destructive case: Delete is held below a `Divider` rather than sorted, so
alphabetising a menu never decides where its delete goes.

Surfaced during: #173, verified against the catalog 2026-08-22.

---

## Document detail cannot delete

`DocumentDetailView`'s toolbar offers Preview, Share and View ▸, plus an Edit button. The row's
context menu offers all of those **and Delete**. So the one screen dedicated to a single document is
the one screen that cannot delete it — you have to go back to the list and long-press the row.

It is not just a missing menu item. Delete today is a row concern:
`DocumentRowReducer` confirms via `DocumentDeleteConfirmationPresenter`, then sends
`.delegate(.deleteDocument)`, and `DocumentListReducer` turns that into
`runDeleteDocuments(ids:server:)` and drops the id from `state.documents`. The detail screen is
pushed onto `state.path`, so deleting from there has to do the same work *and* pop itself — a
delegate the list handles by deleting and removing the path element, rather than anything the
detail reducer can finish alone.

Worth deciding at the same time whether Edit should stay a toolbar button while Delete goes in the
menu, or whether both belong in one place.

Surfaced during: #173, 2026-08-22.
