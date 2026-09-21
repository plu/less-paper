# A search field on the document list that finds more than documents

The web client's global search, brought to iOS: typing three characters into a search field on the
Documents list shows what matched, grouped into sections for documents, saved views, tags,
correspondents, document types, storage paths and custom fields. Tapping a document opens it.
Tapping anything else filters the list behind by it, landing you in the Documents tab with
selection, bulk edit and the filter sheet all live.

## Context

The app has no global search. The Documents list has a filter sheet (`DocumentFilterView`), reached
by the magnifying glass in the top-leading toolbar, whose search field takes a title, a title and
content, an ASN, a custom field value or an advanced full-text query — but every one of those
searches only ever returns documents. To find the correspondent called *Stadtwerke* you open
Settings, then Correspondents, then search there.

The web client solves this with one box in the app frame. It debounces 400ms, requires three
characters, calls `GET /api/search/`, and renders the response as labelled sections in a dropdown.
Each row has a primary action: documents and saved views open, while tags, correspondents, document
types and storage paths filter the document list by the thing you clicked, and users, groups,
custom fields, mail accounts, mail rules and workflows open an edit dialog.

That endpoint is available on every server this app supports. It predates the floor set by
`ApiVersion.minimumSupported = 8` (paperless-ngx 2.15.3), so no version branch is needed.

Probed against a live 3.x instance, `GET /api/search/?query=man` answers with `total` and twelve
arrays. The server caps each array — three documents for a query whose `total` was seven — through
`PAPERLESS_GLOBAL_SEARCH_MAX_RESULTS`, and that cap is not client-controllable. Under three
characters the endpoint answers `400 Query must be at least 3 characters`. There is a separate
`GET /api/search/autocomplete/?term=…` returning a flat array of index tokens, which the web's
global search box does not use.

Three properties of the real payload shaped the design more than the documented behaviour did:

- **Documents arrive with their full `content`.** A response carrying a sixteen-page filing and a
  seven-page letter runs to tens of kilobytes of OCR text, none of which a result row displays.
  `truncate_content`, `fields` and `full_perms` were each tried against the endpoint and returned
  byte-identical responses, so there is no server-side lever. The only mitigations are on the
  client: debounce, cancel in flight, and never retry a keystroke automatically.
- **Results carry `owner` and `user_can_change: false`.** A search can return objects the signed-in
  user may not edit, so any edit affordance needs gating that a filter action does not.
- **The search term would reach the diagnostics log.** `LogRedaction.sensitiveKeys` matches query
  item names by containment against `auth`, `token`, `key`, `secret` and friends. `query` is not
  among them, so one failed request to `/api/search/?query=…` writes the term verbatim into the file
  a user shares with support. A term can be a person's name.

## Decisions

**It lives on the Documents list, not in a tab of its own.** A fifth tab was the first choice and was
reversed: a dedicated search surface has to own a filtered document list to push, and neither
`DocumentListView` nor `InboxView` can be pushed — both open their own `AdaptiveNavigationView`, and
`DocumentListReducer` pushes the document detail onto its own `path`. Hosting search where the list
already is removes that problem completely. Tapping a correspondent sets `filter.input` on the
reducer that is already on screen; selection, bulk edit, pagination, saved views and the status bar
all come along unchanged, and nothing is duplicated.

The objection this overrides — two search inputs on one screen — is weaker than it looks. The filter
sheet's search field is inside a sheet, so the two are never visible together. They divide cleanly:
the bar jumps to a thing, the sheet refines a query.

**The field is visible at rest.** This reverses the decision this document originally recorded, and
the reversal is worth keeping rather than editing away.

**Where it sits depends on what is around it, and the two contexts disagree** — which is the single
most expensive thing anyone working on this screen can fail to know. In the **running app** the
field renders at the **top**, under the navigation bar, because `MainView` embeds this list in a
`TabView`. In the **view-level snapshot references** it renders at the **bottom**, because those
render `DocumentListView` alone with no tab bar. Both were observed directly: the app via
`snapshot_ui` on a launched build, recorded at `UITestSupport/Screens/DocumentListScreen.swift:65`;
the references by eye. The table below was measured against the **references**, so read it as a
statement about them, not about the app.

The original decision was that the field would hide until the list is pulled down, on the strength
of `FavoriteListView`: it ships `.searchable` on a plain `List` under
`.navigationBarTitleDisplayMode(.inline)`, and its recorded reference
(`Snapshots/FavoritesFeatureTests/FavoriteListViewTests/testSnapshot_populated.populated.png`)
shows no field at rest. That precedent is real but does not transfer. `FavoriteListView` declares
**no toolbar**; `DocumentListView` declares `ToolbarItem(placement: .bottomBar)` through
`documentListBottomToolbar`, and on iOS 27 that changes where `.searchable` puts the field.

Three configurations were built and measured against the seven `DocumentListViewTests` references:

| Configuration | Result |
|---|---|
| `.automatic` (no `placement:`) | glassy search bar at the bottom, over the last row |
| `.navigationBarDrawer(displayMode: .automatic)` | expanded capsule under the inline title, list pushed down ~120pt |
| bottom-bar `ToolbarItem` declaration gated on `isActive` | identical to `.automatic` |

The drawer does not collapse under an `.inline` title, so `.automatic` and `.always` render alike.
Gating the bottom bar makes things *worse* rather than better: the placement logic runs the other
way round — when the bottom bar carries real content iOS moves search to the top, and when the bar
is empty or absent it puts search in the bottom. Removing the phantom bar is precisely the
condition that selects bottom placement.

So on this screen the field cannot be hidden at rest, and the choice was between a visible field
and moving search somewhere else entirely. The visible field was chosen: it is the iOS 26/27 system
idiom for a screen with a bottom bar, and it answers the discoverability objection that hiding the
field raised in the first place. The cost is a re-record of the seven references, measured
afterwards as exactly a 48pt bottom-inset delta and nothing else.

**The status pill is left exactly as it was**, drawn by a plain `.overlay(alignment: .bottom)`,
identical to `InboxView`. This too is a reversal worth recording, because the reasoning that
produced the first answer was sound and still wrong.

In the references the search field lands on the last document row and pushes the status pill into
it. The first fix widened that overlay into a full-width opaque band so the pill sat clear. It was
then removed, because the collision it fixes does not exist in the app: the app renders the field at
the top, and the band would have cost roughly 38pt of the final row — opaque, reserving no space,
unscrollable — for every user on every screenful, to fix something none of them would ever see.

**So the references show the pill close to the field, and that is not a bug.** A future reader who
"fixes" it reintroduces the occlusion. `DocumentListViewTests` carries a comment saying so; leave
it there.

**The toolbar is left alone.** Its magnifying glass keeps opening the filter sheet. Re-iconing it to
a filter symbol would divide the two affordances more clearly, and was considered and declined: it
changes a control users already know, for a gain that only matters on the first use.

**Seven sections; the other five types are not decoded at all.** Documents, saved views, tags,
correspondents, document types, storage paths, custom fields. Users, groups, mail accounts, mail
rules and workflows are dropped, because the primary action is "filter the document list by this"
and none of them can become a filter rule — a user could become an owner filter, but
`DocumentFilterInput` has no owner rule today and adding one is separate work. Rendering them as
inert rows would add surface without capability.

**Documents open; everything else filters.** This mirrors the web's primary action and is the whole
point of the feature. The web's secondary actions — download a document, edit a tag — are left out:
`user_can_change: false` is real in production data, and gating an edit affordance correctly is its
own design.

**A tap replaces the filter rather than merging into it.** What the web does, and the filter sheet is
one tap away for anything more elaborate. Merging would leave the user guessing which of two
correspondents is still applied.

**Results survive dismissal.** The query and its results stay in state when the field loses focus, so
reopening the field brings the same results back without a round trip or retyping. This recovers most
of what a push-and-go-back navigation would have given.

**A child reducer, not more cases on `DocumentListReducer`.** That reducer is already 613 lines
carrying import, selection, bulk edit, saved views, tips and the server switcher.
`DocumentSearchReducer` is scoped into it the way `DocumentSelectionReducer` and
`DocumentImportReducer` already are, and talks back through a `Delegate`.

**The five filterable entity types are resolved against the shared caches.** The search payload
carries no `document_count`, so a `Tag` decoded straight from it arrives with `documentCount: 0` —
and that value would then flow into `filter.input.tag.selection` and be rendered by the filter
sheet. Tags, correspondents, document types, storage paths and custom fields are each looked up by
id in the existing `@Shared(.tags(server))` and its siblings, falling back to the decoded value when
the cache has not seen it yet. This is the same instinct as `DocumentFilterInput.resolve(_:in:)`.
Documents and saved views are used as decoded: a document row needs only its id, title and created
date, and a saved view is handed straight to the existing `savedViewButtonTapped` path.

**`total` is dropped.** It counts matches across all twelve types, five of which are not shown.
Displaying it would state a number the screen contradicts.

**`LogRedaction` gets an exact-match list beside its containment list.** Adding `"query"` to
`sensitiveKeys` would also redact `custom_field_query`, whose value is genuinely diagnostic for the
filter feature. A second list matched by exact name, holding `query` and `term`, redacts the search
endpoints without touching anything else.

## Architecture

```
DocumentListView
  └─ List
      └─ .searchable(text: $store.search.searchText)
          └─ .searchSuggestions { DocumentSearchResultsView(store:) }

DocumentListReducer
  └─ Scope(state: \.search, action: \.search) { DocumentSearchReducer() }
       │
       │  delegate
       ▼
  documentTapped(Document.Id)          → existing openDocument push
  filterRequested(DocumentFilterInput) → replace filter.input, clear savedView, reload
  savedViewTapped(SavedView)           → existing savedViewButtonTapped path
  queryCommitted(String)               → searchType = .titleContent, searchValue = query

DocumentSearchReducer
  searchText changed
    ├─ trimmed.count < 3 → clear results, cancel in flight        (the 400 never happens)
    └─ otherwise         → 400ms debounce → GlobalSearchUseCase → results
                           .cancellable(id: CancelID.search, cancelInFlight: true)

GlobalSearchUseCase (ApiInterface) → GlobalSearchRepository (ApiImplementation)
                                     GET /api/search/?query=…
```

The debounce is the idiom already in `DocumentFilterReducer+Effect.swift:53-60`: a
`@Dependency(\.continuousClock)` sleep of 400 milliseconds followed by a `searchDebounced` action,
made cancellable with `cancelInFlight: true`. Reusing it keeps the two searches on the screen
behaving the same way under the same test-clock pattern.

## Changes

**`Modules/ApiInterface/GlobalSearch/`** — new.

- `GlobalSearchInput.swift`: `query: String`, plus the usual `testValue()`.
- `GlobalSearchOutput.swift`: seven arrays — `correspondents`, `customFields`, `documents`,
  `documentTypes`, `savedViews`, `storagePaths`, `tags` — each decoded with
  `decodeIfPresent ?? []` so a server that omits one (custom fields postdate the endpoint) does not
  fail the whole decode. `total` and the five unsupported types are not decoded.
- `GlobalSearchUseCase.swift`: `@DependencyClient` with
  `execute: @Sendable (_ query: String, _ server: Server) async throws -> GlobalSearchOutput`,
  `previewValue`, `testValue`, and the `DependencyValues.globalSearch` accessor.

**`Modules/ApiImplementation/GlobalSearch/`** — new. `GlobalSearchRepository.swift` and
`GlobalSearchUseCase.swift`, copied in shape from `Statistics`. The use case resolves each decoded
entity against its shared cache before returning.

**`Modules/DocumentsFeature/DocumentSearch/`** — new.

- `DocumentSearchReducer.swift` — `searchText` binding, `results`, `isLoading`, `error`; the
  `Delegate` above. The flag is `isLoading` rather than `isSearching` so it cannot be confused with
  SwiftUI's `\.isSearching` environment value, which the fallback in Risks may end up reading.
- `DocumentSearchReducer+Effect.swift` — the debounce and the use-case call.
- `DocumentSearchReducer+TestValue.swift` — per the house pattern.
- `DocumentFilterInput+SearchResult.swift` — five factories, each turning a tapped entity into the
  `DocumentFilterInput` it produces: tag → `.any` selection; correspondent, document type and
  storage path → `.include` selection; custom field → `customFieldQuery` with an `exists` atom.
  (This replaces a `DocumentSearchResult.swift` section enum the design first proposed. The section
  ordering lives in the view instead, which is the only place that needs it.)
- `DocumentSearchResultsView.swift` — sections in order, each omitted when empty, one "No results"
  row when a three-character query matches nothing.
- `DocumentSearchRowView.swift` — each feature's existing SF Symbol, the tag's own colour, and a
  created date on document rows. No client-side truncation; the server already caps each section.

**`Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`** — the `Scope`, the `search`
state, and the four delegate cases.

**`Modules/DocumentsFeature/DocumentList/DocumentListView.swift`** — `.searchable`,
`.searchSuggestions` and `.onSubmit(of: .search)` on the `List` inside `AdaptiveNavigationView`,
the last of these sending the `queryCommitted` action that runs the query as an ordinary
title-and-content filter. `InboxView` is not touched: a global filter applied there would fight the
inbox filter that defines the screen.

**`Modules/Logging/LogRedaction.swift`** — `exactSensitiveKeys = ["query", "term"]`, checked in
`isSensitive(_:)` alongside the containment list.

**`Modules/DocumentsFeature/Resources/Localizable.xcstrings`** — the section headers, the field
placeholder and the no-results text, in `en` and `de`, `"extractionState": "manual"`, keys sorted.

## Testing

- `DocumentSearchReducerTests`: the debounce over a test clock; a query under three characters
  clearing results and issuing no request; cancel-in-flight on a second keystroke; each of the four
  delegates; a failed request leaving the previous results in place and raising no toast. The
  reducer takes no `Logging` dependency and `DocumentsFeature` gains none: `ApiClientDelegate.swift:141`
  already records every failed request centrally, which it calls "the one place that has to
  remember to log".
- `GlobalSearchOutput` decoding from a recorded fixture, including one payload with no
  `custom_fields` key, and one entity absent from the shared cache to exercise the fallback.
- `LogRedactionTests`: `?query=…` redacted, `?custom_field_query=…` kept.
- Snapshots of `DocumentSearchResultsView` populated and empty.
- One `AppUITests` journey, **read-only**: it types a term, asserts the Tags section offers the
  matching tag, taps it, and asserts the narrowed count — mirroring `DocumentBrowsingJourneyTests`.
  It reads the seeded corpus and creates nothing, which is simpler and safer than the
  create-and-tear-down shape this design first proposed: the seed's entities are unowned, so they
  are visible to whichever user the journey runs as.

  The closing assertion is the count, not the presence of a document. Asserting that a document
  still exists after tapping a tag proves nothing — it is in the unfiltered corpus too, so the test
  would pass while the filter was broken. The count can only be satisfied by genuine narrowing, and
  it is checked against the unfiltered total so it cannot be vacuous.

## Out of scope

- `GET /api/search/autocomplete/` word completion for the advanced search type in the filter sheet.
  It is a genuinely separate feature against a different endpoint, and its suggestions are raw index
  tokens — OCR debris like `formw8ben` and `2022est1a011net` comes back alongside real words, so it
  needs its own thinking about what is worth showing.
- Edit affordances on entity rows, the web's secondary action.
- Users, groups, mail accounts, mail rules, workflows.
- A `db_only` setting. The web has one; nothing here needs it yet.
- Search on the Inbox tab.

## Risks

**`.searchSuggestions` is system-styled.** The suggestions overlay may not accept
`m3SurfaceContainerLowest` and the design system's row treatment. If it fights, the fallback is a
child view reading `@Environment(\.isSearching)` driving an `.overlay` on the list, which gives full
control of the presentation at the cost of not being the idiomatic modifier. Try the idiomatic one
first and switch only on evidence.

**Payload weight is unavoidable.** Every search transfers full document content that nothing
displays. The debounce and cancel-in-flight bound how often that happens, but a user typing on a
slow connection will still feel it, and there is no endpoint parameter that helps.

**The references and the app disagree about where the field sits, and only one of them is what
users get.** Everything measured against a `DocumentListView` rendered alone — placement, the pill's
proximity, the 48pt bottom inset — describes the reference, not the product. Every wrong turn on
this screen came from forgetting that, including a widened status band that shipped briefly and was
removed. Verify any future claim about this layout against a launched build, not a reference image.

**Half this screen's references cover no navigation chrome.** The light `DocumentListViewTests`
references render no toolbar icons and no search field, while their dark twins render both. This
predates the feature — verified byte-identical above the bottom strip across the change — but it
means the light references pin almost nothing about the toolbar or the field, and a regression
there would be caught only by the dark half.
