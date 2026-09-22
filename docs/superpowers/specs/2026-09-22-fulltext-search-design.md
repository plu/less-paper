# Title-and-content search on the Tantivy index, gated on API version 10

The filter sheet's title-and-content search stops sending the deprecated `title_content=` and sends
`text=` instead — but only to a server that advertises API version 10, because on anything older
`text=` is not rejected, it is **ignored**, and the search silently returns every document.

## Context

`DocumentFilterInput.filterRules` emits `FilterRuleType.titleContent` (rule 19) for the sheet's
default search type, and `FilterRuleType.queryItemName` maps it to `title_content`. paperless-ngx
deprecated that parameter in 3.0.0 and its implementation says why — `src/documents/filters.py`:

```python
@extend_schema_field(serializers.CharField)
class TitleContentFilter(Filter):
    # Deprecated but retained for existing saved views. UI uses Tantivy-backed `text` / `title_search` params.
    def filter(self, qs: Any, value: Any) -> Any:
        value = value.strip() if isinstance(value, str) else value
        if value:
            logger.warning(
                "Deprecated document filter parameter 'title_content' used; use `text` instead.",
            )
```

Every search is therefore an `icontains` scan over every document's OCR text, and writes a
deprecation warning into the server log while it runs. `text=` is answered from the Tantivy index
instead.

### What was measured

Against the three containers on the dev host, `GET /api/documents/?page_size=1&<param>` with a term
matching nothing (`zzzqqqnomatch`), and the server's own version headers:

| server | `x-api-version` | `text=` | `title_search=` | `title_content=` |
|---|---|---|---|---|
| 2.15.3 (`:8030`) | 8 | **count = 1 of 1** | **count = 1 of 1** | count = 0 |
| 2.19.6 (`:8040`) | 9 | **count = 1 of 1** | **count = 1 of 1** | count = 0 |
| 3.0.5 (`:8000`) | 10 | count = 0 | count = 0 | count = 0 |

**This is the whole reason the change needs a version branch.** django-filter drops a query
parameter it does not know, so on a pre-3.0 server `?text=anything` is not a `400` and not an empty
result — it is the unfiltered document list, returned as though it were the answer. A user on
2.19.6 would type a search term and be shown their entire archive with no indication that anything
went wrong. Sending `text=` unconditionally is not a slow path, it is wrong results.

### The version boundary is exact

`text=` and `title_search=` arrived in [PR #12485](https://github.com/paperless-ngx/paperless-ngx/pull/12485),
merged 2026-04-03, released in **3.0.0**. That same release bumps the API version:

```ts
// src-ui/src/environments/environment.prod.ts @ v3.0.0
  apiVersion: '10', // match src/paperless/settings.py
  version: '3.0.0',
```

```python
# src/paperless/settings.py @ v2.19.6
    "DEFAULT_VERSION": "9",  # match src-ui/src/environments/environment.prod.ts
    "ALLOWED_VERSIONS": ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
```

So API version 10 and the Tantivy text parameters ship together, in the same release, and there is
no version of paperless-ngx that has one without the other. Rule types 48 and 49 tell the same
story from the other end: `grep FILTER_SIMPLE_TEXT src-ui/src/app/data/filter-rule-type.ts` finds
nothing at v2.19.6 and finds it at v3.0.0.

### The swap does not change what matches

`src/documents/search/_query.py` @ v3.0.0:

```python
DEFAULT_SEARCH_FIELDS = ["title", "content", "correspondent", "document_type", "tag"]
SIMPLE_SEARCH_FIELDS = ["simple_title", "simple_content"]
TITLE_SEARCH_FIELDS = ["simple_title"]
_SIMPLE_FIELD_BOOSTS = {"simple_title": 2.0}
```

`text=` searches title and content and nothing else, which is exactly what `title_content=` does.
It is not the advanced `query=` search, which also reaches correspondent, document type and tags —
so the sheet's existing `.advanced` search type stays distinct and untouched.

Probed on the 25-document dev corpus, the two agree, including on mid-word substrings that a
tokenised index might have been expected to miss:

| query | `title_content=` | `text=` |
|---|---|---|
| `Rechnung` | 8 | 8 |
| `echnung` | 8 | 8 |
| `abrechnung` | 4 | 4 |
| `Telekom Rechnung` | 4 | 4 |

`text=` also honours `ordering=` identically — `text=Rechnung&ordering=-added` and
`title_content=Rechnung&ordering=-added` both return `22,21,20,19,17,16,15,14`. There is no
relevance ordering forced on the caller and no pagination surprise.

### There is a bug here already, on every 3.x server

`DocumentFilterInput.init(filterRules:server:…)` has no `case` for `.simpleText`, so rule 49 falls
through to `default: unsupportedFilterRules.append(filterRule)`. Unsupported rules are appended
back verbatim when the input is turned into rules again (`DocumentFilterInput.swift:403`).

The consequence today: open a saved view that the **web client** created on a 3.x server with a
title-and-content search, and the filter is applied — the list is correctly narrowed — but the
search field in the filter sheet is **empty**. The term is invisible and uneditable, and clearing
the field does not clear it. Rule 48 does the same thing to a web-authored title search. Fixing the
read side fixes that independently of any version gate.

### Two things from the idea note that are already done

`docs/ideas.md` flags `truncate_content=true` and `page_size` as separate wins. Both are already in
the code and need no work:

- `truncate_content: "true"` is on all three document requests that carry filter rules —
  `GetDocumentsInput`, `GetDocumentsByIdsInput` and `GetAllDocumentIdsInput`
  (`DocumentsRepository.swift:288`, `:298`, `:325`), and has been since the initial commit. Measured on the
  dev corpus it caps `content` at 550 characters: 10158 characters total across 25 documents
  becomes 3249.
- `PageSize.default` is already 100, the same `page_size` the web client sends.

The idea note should be updated to say so rather than left implying there is work there.

## Decisions

**The gate is `apiVersion >= 10`, not the `x-version` string.** The negotiated integer is already
fetched, negotiated and persisted per server by `NegotiateApiVersionUseCase`, and
`ApiVersion.clientMaximum` is already 10. It needs no semver parsing, no fork handling, and — as the
table above shows — it is exactly as precise as the release number for this question. It is also the
same thing the server uses to decide what it will accept, so client and server branch on one value.

**An unknown version reads as the oldest server the app supports.** `SaveSavedViewUseCase` already
establishes both the mechanism and the wording, and this change copies it verbatim:

```swift
@Shared(.apiVersion(server))
var apiVersion: Int?

// Not yet negotiated reads as the oldest server this app supports: the newer shape is the
// one that has to be earned by a version we have actually seen.
let version = apiVersion ?? ApiVersion.minimumSupported
```

The `SharedReaderKey.apiVersion` declaration says the same thing from the other side: *"No default
on purpose. There is no version that is safe to guess."* Absent must mean `title_content=`, which
works on every server in the supported range including 3.x. Guessing the other way is the silent
whole-archive result.

**The translation happens at the API boundary, not in the feature layer, and not in
`queryItemName`.**

`FilterRuleType.queryItemName` stays a pure static table — it is a rule-type-to-parameter mapping
with no server in scope, and threading a version through it would infect `FilterRule.queryDictionary`
and every caller.

The feature layer is the more tempting place and it is the wrong one, for a specific reason.
`DocumentFilterReducer.State.isModified` compares the server's stored rules against the rules the
input produces:

```swift
savedView.filterRules.sorted() == input.filterRules.sorted()
```

If `DocumentFilterInput` emitted rule 49 on a 3.x server, then every saved view still stored with
rule 19 would open already marked as modified, with a live Save button, before the user touched
anything. Keeping the feature layer version-free keeps that comparison honest.

So the upgrade is a function on `[FilterRule]` applied in `ApiImplementation`, where `server` is in
hand and `@Shared(.apiVersion(server))` can be read.

**The input remembers which rule type it was given.** `DocumentFilterInput` gains a stored
`searchRuleType: FilterRuleType?`, set on read from whichever rule was actually seen and emitted
again on write, falling back to `.titleContent` (or `.title`) when there is nothing to remember.

This is not a new idea in this file — `DateFilter.Bound` already carries `ruleType: FilterRuleType?`
for exactly this reason, and `ruleType(for:isLowerBound:)` prefers the remembered one over the
default. The round trip is what it buys: a view stored as 49 is re-emitted as 49, so `isModified`
stays false, and a view stored as 19 stays 19 in the sheet's own accounting while still going out
as `text=` on the wire.

**Saved views are upgraded when saved, never when read.** A view the user does not touch keeps rule
19 on the server; nothing rewrites data behind them. When they do save — and only then — the
boundary writes 49, which is what the 3.0 web client writes for the same search:

```ts
// filter-editor.component.ts @ v3.0.0 — reads either
case FILTER_TITLE_CONTENT:
case FILTER_SIMPLE_TEXT:
  this._textFilter = rule.value
  this.textFilterTarget = TEXT_FILTER_TARGET_TITLE_CONTENT
  break

// …and always writes the new one
filterRules.push({ rule_type: FILTER_SIMPLE_TEXT, value: this._textFilter.trim() })
```

After a save, `DocumentFilterReducer` re-seeds `state.input` from the returned saved view
(`DocumentFilterReducer.swift:145` and `:164`), so the remembered rule type becomes 49 in the same
step and the sheet does not flicker into a modified state.

**Reading rule 48 is in; writing it is not.** The title-only search keeps emitting rule 0
(`title__icontains`), which is not deprecated, is a cheap indexed column, and carries no server
warning. But the read side accepts 48 anyway, because the invisible-filter bug above hits
web-authored title searches identically and the fix is one `case` label. The app will preserve a 48
it was handed and will never choose one. If that asymmetry is judged worse than the bug, drop the
read case and the `searchRuleType` fallback covers it.

**Custom-field text search is out, after looking.** `custom_fields__icontains` (rule 36) carries the
same deprecation warning in `filters.py`, so it was scoped in initially. It came back out because
**upstream's own 3.0 web client still sends it** — `filter-editor.component.ts` pushes
`FILTER_CUSTOM_FIELDS_TEXT` for its custom-fields text target and trips its own warning. Neither
suggested replacement is a substitute: `custom_field_query` (rule 42, which the app already
supports) needs a named field per clause, and the Tantivy form is `custom_fields.<name>:value`
against a JSON field (`_schema.py: sb.add_json_field("custom_fields", …)`). Neither can express
"substring across all custom field values", which is what the sheet's custom-fields search type
means. There is no destination to move it to, so it stays where it is.

## Architecture

```
filter sheet                     ApiInterface                ApiImplementation            server
──────────────────────────────────────────────────────────────────────────────────────────────────
DocumentFilterInput
  searchType    = .titleContent
  searchRuleType                    [FilterRule]
    ├─ nil          → rule 19  ───────────────┐
    ├─ read 19      → rule 19  ───────────────┤
    └─ read 49      → rule 49  ───────────────┤
                                              ▼
                                    [FilterRule].upgraded(forApiVersion:)
                                      version >= 10 : 19 → 49,  0 → 0
                                      version <  10 : unchanged
                                              │
                            ┌─────────────────┼──────────────────┐
                            ▼                 ▼                  ▼
                     GetDocumentsInput  GetAllDocumentIds   SaveSavedViewInput
                            │                 │                  │
                     queryDictionary    queryDictionary      filter_rules
                            ▼                 ▼                  ▼
                        text=…            text=…           rule_type: 49
```

Read side is version-free and lives in `DocumentFilterInput.init`: rules 19 and 49 both set
`searchType = .titleContent`, rules 0 and 48 both set `searchType = .title`, and `searchRuleType`
records which one arrived.

`GetDocumentsByIdsInput` carries no filter rules and is not touched. `/api/search/` — the global
search this branch is built on — takes `query=` and is unaffected.

## Changes

**`Modules/ApiInterface/Shared/FilterRule.swift`** — a new
`func upgraded(forApiVersion version: Int) -> [FilterRule]` on `[FilterRule]`, mapping `.titleContent`
to `.simpleText` when `version >= 10` and returning `self` otherwise. It lives next to `merged` and
`queryDictionary`, the other two collection-level transforms, and takes the version rather than
reading shared state so it stays a pure function that tests can drive directly.

**`Modules/ApiImplementation/Documents/DocumentsRepository.swift`** — the live `getDocuments` and
`getAllDocumentIds` closures read `@Shared(.apiVersion(server))`, fall back to
`ApiVersion.minimumSupported`, and pass the upgraded rules into the `Request` initialiser. The
`input.url` branch of `Request(input: GetDocumentsInput)` is left alone: a pagination cursor is the
server's own `next` link and already carries whatever parameter the first request sent.

**`Modules/ApiImplementation/SavedViews/SaveSavedViewUseCase.swift`** — `body.filterRules` is
upgraded alongside the existing `version >= 10` branch that already strips `showInSidebar` and
`showOnDashboard`. One version read serves both.

**`Modules/DocumentsFeature/DocumentFilter/DocumentFilterInput.swift`**

- `var searchRuleType: FilterRuleType?` on the struct.
- `case .titleContent, .simpleText:` and `case .title, .simpleTitle:` in `init(filterRules:…)`,
  each recording `searchRuleType = filterRule.ruleType` next to the existing `setSearchValue`.
- `searchRuleType = nil` in the reset block alongside `unsupportedFilterRules = []`.
- `filterRules` emits `searchRuleType ?? .titleContent` for `.titleContent` and
  `searchRuleType ?? .title` for `.title`, guarded so a remembered rule type from a different search
  type is never reused after the user switches the picker.

**`docs/ideas.md`** — the entry is rewritten to record that `truncate_content` and `page_size` were
already done, so the next reader does not re-open them, and the custom-fields finding is noted as
its own idea with the reason it is parked.

No new user-facing strings, so no `Localizable.xcstrings` change in any module.

## Testing

- `FilterRuleTests`: `upgraded(forApiVersion:)` at 8, 9 and 10 — 19 becomes 49 only at 10; 0, 20,
  36 and 42 are never rewritten at any version; an empty array round-trips.
- `DocumentFilterInputTests`: a saved view carrying rule 49 produces `searchType == .titleContent`
  with the term in `searchValue` and **not** in `unsupportedFilterRules` — this is the regression
  test for the invisible-filter bug, and it fails on `main` today. The same for rule 48 and
  `.title`. Round-trip tests that 19 in produces 19 out and 49 in produces 49 out.
- `DocumentFilterReducerTests`: a saved view stored with rule 19, loaded on a server negotiated at
  10, reports `isModified == false`. The same view after `saveButtonTapped` and a response carrying
  49 also reports `isModified == false`. These two are the load-bearing tests for the boundary
  decision — put the translation in the feature layer and the first one fails.
- `DocumentsRepositoryTests`: the request built for a negotiated 9 carries `title_content=`, and for
  a negotiated 10 carries `text=`; with no negotiated version stored it carries `title_content=`.
- `SaveSavedViewUseCaseTests`: extend the existing version-branch tests so the 10 case also asserts
  `filter_rules` went out with `rule_type: 49` and the 9 case with `rule_type: 19`.
- No snapshot changes. Nothing on screen moves — the picker still reads *Title & content*.

**Acceptance, measured on a production-sized corpus.** The dev instance cannot show any of this:
25 documents with 10158 characters of content in total, where a full scan is free. Before merging,
run the same search against a real archive on 3.x with `title_content=` and with `text=` and record
both wall-clock times in this document. The correctness gate stands on its own; the speed claim
that started this should not be merged unproven.

## Out of scope

- Title-only search moving to `title_search=` (rule 0 → 48) on the write side. Read support is in;
  the swap is not. `title__icontains` is not deprecated and is not the slow one.
- Custom-field text search (rule 36). See the decision above — upstream has not moved off it either.
- `truncate_content` and `page_size`. Already done; see Context.
- Trimming the search value before sending it. The web client does `.trim()`; the app does not, and
  with a tokenised index leading whitespace changes nothing. Worth aligning some day, not here.
- The advanced (`query=`) and ASN search types, which are unaffected.
- Any migration of saved views the user has not saved.

## Risks

**A fork or a downstream build that advertises 10 without the Tantivy parameters would break
silently**, in exactly the way pre-3.0 servers do. Nothing in the API surface lets a client tell the
difference, because the failure is an ignored parameter rather than an error. This is accepted: the
same assumption already underpins the `version >= 10` branch in `SaveSavedViewUseCase`, and a
capability probe would cost a request per server and be no more reliable.

**The `searchRuleType` fallback is easy to get wrong when the search type changes.** If the user
loads a view stored with rule 49, then switches the picker to *Title*, a naive implementation emits
rule 49 with a title search. The guard is in `filterRules`, and `DocumentFilterInputTests` should
cover the switch in both directions.

**Ordering and matching were measured on 25 documents.** They agreed exactly, but a corpus that
small cannot exercise stemming, stop words or the `simple_title` boost of 2.0. The production
measurement above is the place to sanity-check that results still look right, not just that they
arrive faster.
