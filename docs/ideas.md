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

## Filter documents by date

The filter sheet has no date field, so date rules can only be passed through untouched — they are
carried in `DocumentFilterInput.unsupportedFilterRules` and are neither shown nor editable. A saved
view like "Invoices 2026" (`created__date__gt = 2026-01-01`) is applied correctly, but the user has
no way to see or change the year from the app.

The awkward part is that Paperless-ngx has four overlapping spellings per field, and whichever one
a saved view uses has to be written back unchanged — normalising an exclusive bound to an inclusive
one silently shifts the user's boundary by a day:

- legacy exclusive `createdBefore` (8) / `createdAfter` (9) → `created__date__lt` / `__gt`
- modern inclusive `createdTo` (43) / `createdFrom` (44) → `created__date__lte` / `__gte`
- the same two pairs for added: 13/14 and 45/46
- plus `createdYear` / `Month` / `Day` (10/11/12) and `modifiedBefore` / `After` (15/16)

Shape would follow the existing fields: a `DateFilter` struct in `DocumentFilterInput` alongside
`ListFilter` and `TagFilter`, holding the field (created/added) and a from/to bound that each
remember the rule type they were parsed from; a `DocumentFilterDateField` view plus a destination on
`DocumentFilterReducer.Destination`, mirroring `DocumentFilterGenericValueField`. Values format as
`yyyy-MM-dd`. Wants a UX decision first — single range versus presets like "this year", and whether
created and added are one field or two.

Surfaced during: the `unsupportedFilterRules` fix.

---

## `hasAnyTag` loses its value on a round trip

`DocumentFilterInput` parses `hasAnyTag` (rule 7) into `tag.rule = .notAssigned` while ignoring the
rule's value (`DocumentFilterInput.swift:152`), and always re-emits `"0"` (`:321`). A saved view
built with `is_tagged=1` ("has any tag") therefore comes back as `is_tagged=0` ("not tagged").

**This is worse than a save-payload problem.** `runGetDocuments` sends
`state.filter.input.filterRules`, which is the same re-emitted list — so simply *selecting* such a
saved view queries the server for the inverted set and shows the user untagged documents. Saving
then persists the inversion, and the sheet reports itself as modified in the meantime because the
value no longer matches the saved view.

The tag rule needs a third state to model this; passing the rule through untouched is not an option
because the tag field does emit `hasAnyTag` itself, so a passthrough copy would duplicate it.
`DocumentFilterTagRule` is a small three-case enum, so the change is contained — the work is in the
parse/emit pair, the picker UI and its localized strings.

Surfaced during: the `unsupportedFilterRules` fix. Re-verified 2026-08-15, including the query path.

---

## Filter rules pointing at uncached entities are dropped

`DocumentFilterInput.init(filterRules:…)` resolves correspondent, document type, storage path and
tag ids against the `@Shared` caches and silently drops any id that is not there — deliberate, and
covered by the `skipsInvalidIds` test. If a cache is ever empty or stale when a saved view is
loaded, that view's rules are lost from both the query and the save payload, and the sheet shows a
phantom "modified" state.

Same failure mode as the date rules, but passthrough does not help: these rule types are re-emitted
from the selection, so keeping an unresolved copy would duplicate them. Closing it properly means
either guaranteeing the caches are warm before a saved view is applied, or holding unresolved ids in
the selection so they survive and can be rendered as a placeholder.

Surfaced during: the `unsupportedFilterRules` fix.

---

## Bulk delete from a selection

`DeleteDocumentsUseCase` already takes `[Document.Id]` and goes through `bulk_edit`, precisely so a
"delete the selected documents" action would need no API work. Nothing calls it with more than one
id — the row context menu is the only entry point.

The UI would sit in `DocumentListBottomToolbar` next to the existing bulk edit actions, and would
want a confirmation naming the count rather than a title. Note the list-side cleanup in
`documentsDeleted` is already written for a set of ids, so it should carry over unchanged.

Surfaced during: `docs/plans/2026-08-14-delete-document.md`.

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
