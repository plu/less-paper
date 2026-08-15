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
actually split. Of 170 keys, **110 (64%) are used by exactly one module**, so per-module catalogs
would not duplicate much — but the 56 genuinely shared ones (`cancel`, `close`, `save`, `name`,
`title`, `url`, `tags`, `deleteConfirmation`, …) need a home.

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
