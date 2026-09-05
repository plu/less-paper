# Ideas

Good-to-implement ideas surfaced while working on something else and deliberately left out of
scope at the time. Not a commitment and not prioritised — a place to park things so they are not
rediscovered from scratch.

When picking one up, move it out of here into a design in `docs/superpowers/specs/` and, once that
is settled, a plan in `docs/superpowers/plans/`.

---

## Discover documents that *start* matching a tab's filter

Cross-tab sync propagates document content but deliberately never changes a list's membership.
An edit that makes a document newly match the other tab's filter cannot be detected locally — the
other tab only learns about it on its next fetch.

Closing this needs either a client-side filter-rule evaluator (large, and it still cannot invent
documents the client has never loaded) or a re-fetch of the other tab. Both were rejected as
disproportionate at the time.

Surfaced during: `docs/superpowers/specs/2026-08-12-cross-tab-document-sync-design.md`.

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

Surfaced during: `docs/superpowers/specs/2026-08-12-cross-tab-document-sync-design.md`, re-verified 2026-08-15.

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

Surfaced during: `docs/superpowers/specs/2026-08-14-delete-document-design.md` and the #131 inbox count work.

---

## Two unmeasured CI leads

Both plausible, neither timed:

- `mise/scripts/run_tests.sh` passes `--clean` to `tuist test`. `ci:clean` already runs
  `git clean -ffdx && git reset --hard`, so the workspace is pristine; `--clean` additionally
  discards derived data on a runner where it would otherwise persist. Worth timing now that the
  binary cache and selective testing both depend on what survives between runs.

The other two are settled: selective testing is on, and `ci:cache` warms only the external
dependencies. Warming `all-possible` — the internal modules too — was tried in #60 and reverted:
`ApiInterface`'s `URL.projectRoot` resolves a bare `#filePath` at compile time, so a binary-cached
`ApiInterface` would carry the path of whatever machine built it. `Tuist.swift` carries the detail.

Surfaced during: the CI runtime investigation, 2026-08-15; re-checked 2026-08-30.

---

## Remember the last bulk-rename template

`DocumentBulkEditTitleReducer.State.template` opens on `{title}` every time — a no-op the user
extends, rather than the blank it originally started as. What it still does not do is remember the
template you used last time, so `{created_year}-{correspondent}` gets retyped for every batch. An
`@Shared(.appStorage)` key per server would cover it, but note the caveat already recorded under
"`appStorage` does not use the app group".

Surfaced during: `docs/superpowers/specs/2026-08-16-bulk-edit-title-design.md`.

---

## The bottom toolbar is full

Five icons plus the overflow menu is the maximum: measured on an iPhone 17 Pro (402pt), six span
411pt and clip at both ends. "Edit title" went into the overflow menu for that reason alone, which
makes it much harder to discover than the four edit actions beside it.

Anything else that wants a place there needs the row to change shape first — a scrolling row, a
second line, or grouping the four edit actions behind one "Edit" menu.

Surfaced during: `docs/superpowers/specs/2026-08-16-bulk-edit-title-design.md`.

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

Surfaced during: `docs/superpowers/specs/2026-08-16-filter-match-count-design.md`.

---

## A first-run message for an empty archive

`DocumentListEmptyView` now says something specific for an error, an inbox with no inbox tag, an
empty inbox and a filter that matches nothing. The fifth case — a genuinely empty archive —
still reads "No documents found".

For a new user who has uploaded nothing that is an onboarding moment, not a failure, and it wants
copy that belongs with a wider first-run story rather than a lone string swap.

Surfaced during: `docs/superpowers/specs/2026-08-16-document-list-empty-states-design.md`.

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
The XCUITests talk to `ci`: `Module+InfoPlists.swift` puts `PAPERLESS_TEST_URL` in every target's
Info.plist, defaulting to `http://localhost:9000`.

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

## Audit the remaining test targets for bare `@Suite`

A suite declared as a bare `@Suite` with no `.dependencies()` trait relies on some other suite in
the same bundle having established `\.timeZone` before it runs, and fails alone with an issue at
swift-dependencies' `TimeZone.swift:21` — the "blank TimeZone dependency" report. The coupling is
invisible until the suite is run by itself, so CI stays green.

The cause is a process-global capturing a test-scoped dependency: `JSONDecoder.apiDecoder` is a
lazy `static let`, and `configureForApi` builds `DateFormatter`s that ApiInterface's
`DateFormatter(dateFormat:)` initialises with `Dependency(\.timeZone)`. Whichever test touches the
decoder first decides the time zone for the whole process. `JSONEncoder.apiEncoder` has the same
exposure through `DateFormatter.createdDate`.

**Done:** `ApiInterfaceTests` — all 56 suites run one at a time, the 30 that reported the issue now
carry the trait. `ServersFeatureTests` — `ServerRowReducerTests`, the suite that surfaced this,
plus a sweep of the other seven.

**Left:** every other test target. `ApiImplementationTests` has the same profile — 10 of 55 files
carry the trait — and is the obvious next one. The sweep is a `test-without-building` run per
suite, grepping for `TimeZone.swift`, which is slow but reliable; static analysis is not, because
suites reach the decoder indirectly.

The structural fix would be to stop those globals resolving `\.timeZone` eagerly. That is not just
a refactor: the API's `"yyyy-MM-dd"` format is the one with no offset of its own, so pinning it
changes which instant a bare date maps to, and DocumentsFeature's display formatter does not pin a
zone. Both sides have to move together or dates shift by a day outside GMT.

Surfaced during: `docs/superpowers/specs/2026-08-22-confirmation-popup-migration-design.md`, 2026-08-22.

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

`DocumentDetailView`'s toolbar is an ellipsis menu — Preview, Share and View ▸ — beside an Edit
button. The row's context menu offers all of that **and Delete**. So the one screen dedicated to a
single document is the one screen that cannot delete it — you have to go back to the list and
long-press the row.

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

---

## `StoreKitConfigurationFileReference` only works from an interactive Xcode Run

`Module+Schemes.swift` sets `storeKitConfigurationPath` (`Tuist/Tips.storekit`) only on the "Less
Paper" scheme's `runAction` — the `LaunchAction` in the generated `.xcscheme`. Apple honours that
setting only for an interactive Run from Xcode. Neither `tuist run` nor `simctl launch` triggers it,
because both bypass the scheme's launch action the way Xcode's own Run button does not.

So verifying the tip list (or anything else backed by the local StoreKit configuration) against
real product data cannot be automated from a command line at all — not CI, not a local script. It
needs a human pressing Run in Xcode.

Surfaced during: `docs/superpowers/specs/2026-09-04-tiny-tip-design.md`, 2026-09-04.
