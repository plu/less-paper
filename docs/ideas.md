# Ideas

Good-to-implement ideas surfaced while working on something else and deliberately left out of
scope at the time. Not a commitment and not prioritised — a place to park things so they are not
rediscovered from scratch.

When picking one up, move it out of here and into a `docs/plans/` document.

---

## Refresh the inbox badge after edits

The Inbox tab badge reads `inboxDocumentCount` (`SharedReaderKey+Extensions.swift`), which is
written only by `GetStatisticsUseCase` — and that runs only from `UpdateCacheUseCase`, i.e. when
the selected server changes (`AppReducer.selectedServerChanged`).

So adding or removing an inbox tag leaves the badge stale for the rest of the session, whether the
edit was made from the Inbox tab or the Documents tab.

Fix would be to re-fetch statistics after any edit that touches an inbox tag. Cheap, but it adds a
request to the edit path, so it wants a moment's thought about where to trigger it.

Surfaced during: `docs/plans/2026-08-12-cross-tab-document-sync.md`.

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
