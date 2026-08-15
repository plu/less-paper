# Ideas

Good-to-implement ideas surfaced while working on something else and deliberately left out of
scope at the time. Not a commitment and not prioritised — a place to park things so they are not
rediscovered from scratch.

When picking one up, move it out of here and into a `docs/plans/` document.

---

## Refresh the inbox badge

**Observed in practice:** the number on the Inbox tab bar item is sometimes wrong.

The Inbox tab badge reads `inboxDocumentCount` (`SharedReaderKey+Extensions.swift`), which is
written only by `GetStatisticsUseCase` — and that runs only from `UpdateCacheUseCase`, i.e. when
the selected server changes (`AppReducer.selectedServerChanged`).

So the badge is a snapshot taken at server-selection time and never revised for the rest of the
session. Everything that changes the true inbox count leaves it stale:

- adding or removing an inbox tag, from either tab (single edit or bulk edit)
- deleting a document that carried an inbox tag
- documents consumed server-side while the app is open

Fix would be to re-fetch statistics after any operation that can change the count. Cheap per call,
but it adds a request to several paths, so it wants a moment's thought about where to trigger it —
probably one shared "invalidate statistics" effect rather than a call per site.

Surfaced during: `docs/plans/2026-08-12-cross-tab-document-sync.md`, reinforced by
`docs/plans/2026-08-14-delete-document.md` and a direct user report on 2026-08-15.

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

## Refresh lists after a share-extension import

Importing a document through the share extension does not refresh either document list. The new
document appears only after a manual pull-to-refresh or the next `onAppear` with an empty list.

Surfaced during: `docs/plans/2026-08-12-cross-tab-document-sync.md`.

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
rule's value, and always re-emits `"0"`. A saved view built with `is_tagged=1` ("has any tag")
therefore comes back as `is_tagged=0` ("not tagged") — the filter is inverted, and the sheet reports
itself as modified because the value no longer matches the saved view.

The tag rule needs a third state to model this; passing the rule through untouched is not an option
because the tag field does emit `hasAnyTag` itself, so a passthrough copy would duplicate it.

Surfaced during: the `unsupportedFilterRules` fix.

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
