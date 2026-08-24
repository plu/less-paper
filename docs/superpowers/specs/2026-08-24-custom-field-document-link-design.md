# Filtering by document-link custom fields

## Context

`2026-08-23-custom-field-filter-design.md` delivered filtering by custom field values. One data
type came out unusable: **`documentlink`**.

A documentlink field admits three operators — `exists`, `isnull`, `contains`. `contains` has value
kind `.array`, and the condition editor routes every `.array` value to the select-option sheet.
A documentlink field has no select options, so that sheet is empty and the condition can never be
filled in. The value it needs is not a set of option ids but a set of **document ids**.

The paperless-ngx web UI solves this with a type-ahead: the user types, the client searches
documents by title, and the chosen documents appear as chips. This spec adds the same thing.

### What the web does

Observed in the web client while typing into a `Link · Contains` value field:

```
GET /api/documents/?page=1&ordering=-created&truncate_content=true&title_search=puky
```

Results render as a dropdown of `Title (created)` rows; picking several leaves a row of chips, each
removable.

### `title_search` is `title__icontains`

Verified against the local dev instance (paperless-ngx 3.0.5, `docker/`, port 8000). With
`ordering=-created` pinned, the two parameters returned **identical** result sets for every query
tried — `puky`, `PUKY`, `ky-Loc`, and the multi-word `puky locked` (which both reject, so neither
tokenises):

```
title_search=puky      ordering=-created -> [30, 27, 10, 8]
title__icontains=puky  ordering=-created -> [30, 27, 10, 8]
```

An unknown query parameter is silently ignored and returns all 23 documents, so both parameters are
demonstrably being honoured rather than dropped.

`title_search` is therefore a case-insensitive substring match on the title and nothing more. The
app already speaks `title__icontains` through `FilterRuleType.title`, so the picker reuses
`GetDocumentsUseCase` and this feature adds **no new API surface** — no input type, no use case, no
repository method. A `title_search` field could not have been a `FilterRule` in any case: rule types
are numeric ids that round-trip through saved views, and the server has no rule type for this.

### The value shape

Verified by creating a documentlink field and querying it:

```
["AND",[[19,"contains",[10]]]]     → 200
["AND",[[19,"contains",["10"]]]]   → 200
["AND",[[19,"contains",10]]]       → 400  "Expected a list of items but got type \"int\"."
```

Both element types are accepted; the client emits **numbers**, matching the ids' natural type. An
empty array is already `isComplete == false`, so an untouched condition prunes away and no rule is
sent — the behaviour the rest of the feature relies on.

## Architecture

The condition editor is currently a plain view driven by parent state: `CustomFieldQueryCardsView`
presents it with `sheet(item:)` over `State.Editor`, and it posts `onViewAction` closures back to
`CustomFieldQueryCardsReducer`. That works while editing is synchronous. The picker is not — it
debounces, fetches, and can fail — and putting that in the tree reducer would leave one reducer
owning tree editing, atom editing, option selection and document search.

So the editor is promoted to its own feature, and the picker hangs off it:

```
CustomFieldQueryCardsReducer            tree editing only
    └── @Presents editor
        CustomFieldQueryAtomEditorReducer      one atom: field, operator, value
            ├── @Presents selectOptions        (unchanged behaviour, now a destination)
            └── @Presents documentPicker
                CustomFieldQueryDocumentPickerReducer   search, selection
```

`CustomFieldQueryCardsReducer` keeps `query`, the path arithmetic, and the add/delete/negate
actions. It loses `editorFieldChanged`, `editorOperatorChanged`, `editorValueChanged`,
`editorOptionToggled`, `editorOptionsTapped` and `editorOptionsDismissed`, which move to the editor
reducer, and gains one delegate case: `atomChanged(path:atom:)`.

Writing back stays path-addressed rather than by binding, for the reason already recorded in the
tree reducer: the editor sheet outlives a delete of the row that opened it, and a stale path would
otherwise land on whatever moved into that index.

### `CustomFieldQueryDocumentPickerReducer`

```swift
@ObservableState
struct State: Equatable, Sendable {
    var documents: IdentifiedArrayOf<Document>   // search results
    var isLoading: Bool
    var searchText: String
    var selection: IdentifiedArrayOf<Document>   // resolved, so chips survive a query change
    let server: Server
}
```

`selection` holds whole `Document` values rather than ids because of one behaviour that matters:
**selected documents pin above the results.** Without that, selecting `Puky-Locked`, then searching
`invoice`, makes the selection disappear from the list — still in the query, but no longer visible
or removable. Holding the resolved documents means the pinned rows keep their titles no matter what
the current query returns.

A search runs on a 400ms debounce, reusing the pattern in `DocumentFilterReducer+Effect`, and is
`.cancellable(cancelInFlight: true)` so a fast typist issues one request. An empty query shows the
most recent documents rather than nothing, which is what the web does. Failures go to `.toast`.

Delegate: `selectionChanged([Document.Id])`, emitted sorted so the same selection produces the same
JSON between openings of the sheet.

### Resolving ids to titles

A stored condition holds bare ids. When the editor opens on a documentlink atom with a non-empty
value, it resolves them through the existing `GetDocumentsByIdsUseCase` and shows the titles as
capsules in the value field. An id that no longer resolves — a deleted document — renders as `#10`
rather than vanishing, so the condition stays visible and removable.

### How a link condition reads elsewhere

Per the scoping decision, resolved titles do not travel beyond the picker and the editor's value
capsule. `CustomFieldQuery+Summary` has no document cache and gaining one would mean the filter
sheet could not render until those titles loaded. Instead, a documentlink array renders as a count
using the existing pluralised `numberOfDocuments` key:

> Link contains 3 documents

That covers the card rows and the collapsed **Custom fields** row on the filter sheet.

## Testing

Reducer tests with a stubbed `getDocuments` cover: the debounce firing once for a burst of
keystrokes, an empty query listing recent documents, toggling selection on and off, a selected
document staying pinned when the query no longer matches it, sorted emission, and a failing search
raising a toast without clearing the selection.

Editor-reducer tests cover the destinations opening and the atom being written back through the new
`atomChanged` delegate, replacing the equivalent assertions that live in the cards reducer tests
today.

Snapshot tests at `.iPhone12` cover the picker with: no query, results, a selection pinned above
non-matching results, no results, and loading.

Model tests cover `valueSummary` rendering the document count for a documentlink field, including
the singular case.

## Out of scope

- `title_search` as a distinct API parameter. It is `title__icontains`, verified above.
- Titles in the collapsed filter row or card rows; those show a count.
- Any change to how the other data types are edited. The editor's extraction is a move, not a
  rewrite — the field, operator and value controls keep their current behaviour, and their existing
  snapshots should be unchanged by it.
