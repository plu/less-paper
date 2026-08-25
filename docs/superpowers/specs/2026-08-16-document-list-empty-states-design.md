# Document list empty states

## Context

`DocumentListEmptyView` is the overlay both document tabs show when a load finishes with nothing to
display. It has two branches: an error, or `tray` + "No documents found" + a Reload button.

That second branch covers four situations that mean entirely different things, and gets three of them
wrong:

- **An empty inbox is success.** Every document has been filed. Telling the user nothing was *found*
  frames an achievement as a failure, and the Reload button invites them to go looking for work that
  does not exist.
- **An inbox with no inbox tag configured is a misconfiguration.** `clearForEmptyInbox()` empties the
  list when `isInboxWithoutInboxTags`, so this lands on the same screen. The inbox is structurally
  incapable of ever holding anything, and the app says only "No documents found".
- **A filter matching nothing is a query problem.** Reload cannot help; the filter is the only thing
  that can change. The screen offers the one button that cannot fix it.
- **A genuinely empty archive** is the only case the current message actually fits.

## Design

### The five states

Checked in this order, in `DocumentListEmptyView`. The view as a whole is already gated on
`store.documents.isEmpty && store.isLoaded`, so "the list is empty and settled" is a precondition of
every row below rather than part of any single condition:

| # | Condition | Icon | Title | Button |
|---|---|---|---|---|
| 1 | `store.error != nil` | `exclamationmark.triangle` | the error text | Reload |
| 2 | `filter.isInbox` and `isInboxWithoutInboxTags` | `tag.slash` | `noInboxTagConfigured` | Reload |
| 3 | `filter.isInbox` | `checkmark.circle` | `allCaughtUp` | — |
| 4 | `hasActiveFilter` | `magnifyingglass` | `noMatchingDocuments` | Filter |
| 5 | otherwise | `tray` | `noDocumentsFound` | Reload |

**The order carries the logic and is not incidental:**

- **2 before 3.** Otherwise the app congratulates users whose inbox can never hold anything. This is
  the one ordering that would ship an outright lie.
- **3 and 2 before 4.** The inbox filter *is* a tag filter, so `hasActiveFilter` is true on the inbox
  tab. Checking 4 first would swallow both inbox states.

### Wording and icons

**`allCaughtUp` — "All caught up" / "Alles erledigt".** Warm, unambiguous, and reads as an
achievement rather than an absence. Rejected: *"Inbox zero"*, recognisable to this app's audience but
untranslatable (*"Posteingang null"* is nonsense); *"Nothing to file"*, accurate but flat.

**`checkmark.circle`** at the existing 128pt in `m3OutlineVariant` — the one symbol that cannot be
misread as "something is missing". Rejected: `sparkles`, which reads as decoration, and `tray`, which
the failure state already uses, so success and emptiness would look identical.

**`noInboxTagConfigured` — "No inbox tag configured" / "Kein Posteingang-Tag konfiguriert"**, with
`tag.slash`. Matches the existing `inboxTag` string's terminology.

**`noMatchingDocuments` — "No matching documents" / "Keine passenden Dokumente"**, with
`magnifyingglass`. Short enough for the single `.title3` line `EmptyListView` allows at 60% container
width, and unlike "No documents found" it says *why* there is nothing. The symbol is the one the
toolbar's filter button already uses.

### Buttons

The rule is **Reload appears only where reloading can change the outcome**:

- **State 1** keeps it — the fetch failed and retrying is the fix.
- **State 2 keeps it**, which looks like an exception but is not. Inbox tags come from the server
  (`GetStatisticsOutput.inboxTags`, i.e. tags flagged `is_inbox_tag` in paperless-ngx), so the fix is
  server-side; `rebuildInboxFilterIfNeeded` re-reads them on reload, making Reload exactly the right
  action once the user has fixed it there.
- **State 3 loses it.** An empty inbox is the desired outcome. Pull-to-refresh still works on the
  list, so nothing is lost — the screen simply stops ending in a call to action implying something
  might be missing.
- **State 4 gets Filter instead**, sending the existing `filterButtonTapped`. Reload cannot help when
  the query is the problem. This is the only place an action is added rather than removed; the
  alternative was a dead-end screen whose only fix is a small toolbar button in the far corner.
- **State 5 keeps it** — an archive that looks empty may just have failed to sync.

### State

One computed property on `DocumentListReducer.State`:

```swift
var hasActiveFilter: Bool {
    filter.input != DocumentFilterInput() || filter.savedView != nil
}
```

`isInboxWithoutInboxTags` already exists and is reused as-is.

## Testing

- `DocumentListEmptyViewTests` — a snapshot per state, rendering the view directly rather than
  through the whole list. The five snapshots are the real specification of this change: each one
  pins an icon, a line of copy, and the presence or absence of a button.
- `DocumentListReducerTests` — `hasActiveFilter` is true for a search value, true for a saved view,
  false for a default filter.
- The existing `DocumentListViewTests.testSnapshot_emptyResult` and `testSnapshot_errorResult` keep
  covering the view in context and must come back unchanged, since neither uses an inbox filter.

`DocumentFilter.testValue` gains an `isInbox` parameter, which it does not currently expose.

## Out of scope

- **A first-run message for a genuinely empty archive.** State 5 still reads "No documents found"
  when a new user has uploaded nothing. That is an onboarding opportunity rather than a wrong
  message, and it needs copy that belongs with a wider first-run story.
- **`EmptyListView` gains no subtitle slot.** Every state here fits one line, and the component is
  shared with tags, correspondents, storage paths and saved views — widening its API for a single
  caller is not warranted.
