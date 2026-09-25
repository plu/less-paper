# Offline: rename Favorites, and give its list the documents search bar

Two changes to one screen. The tab called *Favorites* becomes *Offline*, everywhere and down to the
files on disk, and its search field stops being SwiftUI's `.searchable` and becomes the same bar the
Documents list uses.

## Why

**The name was never what the feature does.** A favorite is a thing you like; these are documents
downloaded onto the phone so they can be read with no connection. The code already knew — the
comments in `FavoriteListReducer`, `SaveFavoriteUseCase` and `SnapshotCorpus` all say *offline*
where the types say *favorite*, and the App Store caption has said *Keep what matters, even offline*
since it was written. Only the user-facing name and the symbols disagreed.

**Two search fields on two document lists is one too many.** The Documents list shows a capsule
`Field` as its first row, with a magnifying glass, an inline clear button and an animated cancel
beside it. The Offline list shows the system search bar, which sits above the list, is styled by
UIKit rather than by the app, and collapses on scroll. They are the same gesture on the same kind of
content and they should not look different.

## Decisions taken

| Question | Answer |
|---|---|
| How deep does the rename go | Everything, including the persisted filenames — so a migration is part of the work |
| Verb and icon | *Save offline* / *Remove from Offline*, `arrow.down.circle` in place of the heart |
| Search behaviour | The Documents bar's shell; the instant local filter underneath is unchanged |
| Sequencing | Rename first, search bar second, asset re-record third |
| App Store assets | In scope, re-recorded once both UI changes have landed |

## §1 — The search bar

`DocumentSearchField` and the cancel-button row inside `DocumentSearchBarView` have nothing to do
with documents. The field is a `Field(padding: .x0)` holding a glyph, a `TextField` and a clear
button; the bar adds a cancel button that animates its width and opacity together rather than being
inserted by an `if`, for the reason its own comment gives. Only the TCA plumbing around them is
feature-specific.

Both move into `Components`:

- **`SearchField`** — the styling, unchanged. Takes `isFocused`, `submitted` and `text`.
- **`SearchBar`** — field plus animated cancel. Takes `text: Binding<String>`, a `cancelled`
  closure, an optional `submitted` closure, and a `dismissalCount: Int` whose changes resign focus.

`DocumentSearchBarView` becomes a store wrapper over `SearchBar`, keeping its explicit
`searchTextBinding` — the reducer has no `BindingReducer` and a bindable write would skip the
debounce. `OfflineSearchBarView` is the equivalent wrapper for the Offline list, and it is thin:
there is no debounce, no minimum length and no results view to drive.

`Components` gains `search` and `clearSearch`, copied verbatim from `DocumentsFeature`'s catalogue
in both `en` and `de`. It already has `cancel`. Per the module-owns-its-strings rule the duplication
is the design; `DocumentsFeature` keeps its own copies for whatever else uses them.

**On the Offline list**, the bar is the first row of the `List`, above the document rows, and is
always present — including on an empty list, matching the Documents list. It replaces the current
`if !store.rows.isEmpty || !store.searchText.isEmpty { list.searchable(...) } else { list }`
branch, which exists only because a system search bar over an empty list has nowhere to scroll to.
A row has no such problem, so the branch goes and `OfflineListView.body` gets simpler.

`.scrollDismissesKeyboard(.immediately)` comes across with it: dragging the list is as much a way of
saying *let me see them* here as it is there.

**What does not change:** `visibleFavorites` → `visibleOfflineDocuments` keeps its exact matching —
lowercased substring over title, content, correspondent, document type, storage path and tag names —
and still filters from the first character. The 3-character minimum on the Documents list is the
server's rule (`400 Query must be at least 3 characters`), and there is no server here.

The two empty states stay as they are and keep being two: nothing saved offline yet, which is worth
explaining, and a query that matched nothing, which is not.

## §2 — The rename

### Module

`Modules/FavoritesFeature` → `Modules/OfflineFeature`, and its tests likewise. Inside it,
`FavoriteList/` → `OfflineList/` and `FavoriteRow/` → `OfflineRow/`. Three Tuist manifests carry the
name: `Module.swift` (the enum cases and the two lists they appear in), `Module+Dependencies.swift`
and `Module+Schemes.swift`. The catalogue reaches the target through the synchronized folder, so
there is no `resources:` glob to update.

### Types

| Now | Becomes |
|---|---|
| `FavoriteListReducer`, `FavoriteListView` | `OfflineListReducer`, `OfflineListView` |
| `FavoriteRowReducer`, `FavoriteRowView` | `OfflineRowReducer`, `OfflineRowView` |
| `FavoriteThumbnail` | `OfflineThumbnail` |
| `FavoriteRefreshResult` | `OfflineRefreshResult` |
| `FavoriteListCancelID` | `OfflineListCancelID` |
| `FavoriteSettingsReducer`, `FavoriteSettingsView` | `OfflineSettingsReducer`, `OfflineSettingsView` |
| `FavoriteDocument` | `OfflineDocument` |
| `FavoritesStore`, `\.favoritesStore` | `OfflineStore`, `\.offlineStore` |
| `RefreshFavoritesUseCase`, `\.refreshFavorites` | `RefreshOfflineUseCase`, `\.refreshOffline` |
| `SaveFavoriteUseCase`, `RemoveFavoriteUseCase` | `SaveOfflineDocumentUseCase`, `RemoveOfflineDocumentUseCase` |
| `.favorites(server)` shared key | `.offlineDocuments(server)` |
| `.favoritesDecoder`, `.favoritesEncoder` | `.offlineDecoder`, `.offlineEncoder` |
| `AppTab.favorites`, `MainReducer.favoriteList` | `AppTab.offline`, `MainReducer.offlineList` |
| `DocumentSwipeAction.favorite` | `DocumentSwipeAction.saveOffline` |
| `MarketingScreen.favorites` | `MarketingScreen.offline` |

`Modules/ApiInterface/Favorites/` → `Modules/ApiInterface/Offline/`, same for
`Modules/ApiImplementation/Favorites/`. Two extension files rename with what they extend:
`UseCase+FavoritesStore.swift` → `UseCase+OfflineStore.swift` and `JSONCoder+Favorites.swift` →
`JSONCoder+Offline.swift`.

`DocumentDetailReducer.isOfflineSnapshot` already reads correctly and does not move.

### Icon

`heart` / `heart.fill` → `arrow.down.circle` / `arrow.down.circle.fill`. The tab takes the filled
glyph, as it does today. The swipe action takes the unfilled one, for the reason already written
down in `DocumentSwipeAction.systemImage`: the button names the action, not the state of any one
document, and the row swaps it for a document already saved.

### Strings

Each in the catalogue of the module that shows it, `en` and `de`, `"extractionState": "manual"`,
keys sorted. Values in full so nothing is invented at implementation time:

| Key | en | de |
|---|---|---|
| `offline` | Offline | Offline |
| `saveOffline` | Save offline | Offline speichern |
| `removeFromOffline` | Remove from Offline | Aus Offline entfernen |
| `swipeActionOffline` | Offline | Offline |
| `noOfflineDocuments` | Nothing saved offline yet | Noch nichts offline gespeichert |
| `noOfflineDocumentsFound` | No offline documents found | Keine Offline-Dokumente gefunden |
| `noOfflineDocumentsMessage` | Documents you save offline stay on this device, ready to read without a connection. | Offline gespeicherte Dokumente bleiben auf diesem Gerät und sind ohne Verbindung lesbar. |
| `removeAllOfflineDocuments` | Remove all offline documents | Alle Offline-Dokumente entfernen |
| `offlineUpToDate` | Offline documents are up to date. | Offline-Dokumente sind aktuell. |
| `offlineUnavailable` | Unavailable | Nicht verfügbar |

The three refresh toasts keep their plural variations and change only their nouns:

| Key | en one / other | de one / other |
|---|---|---|
| `offlineRefreshUpdated` | One document updated. / %lld documents updated. | Ein Dokument aktualisiert. / %lld Dokumente aktualisiert. |
| `offlineRefreshFailed` | One document could not be refreshed. / %lld documents could not be refreshed. | Ein Dokument konnte nicht aktualisiert werden. / %lld Dokumente konnten nicht aktualisiert werden. |
| `offlineRefreshUnavailable` | One document is no longer on the server. / %lld documents are no longer on the server. | Ein Dokument ist nicht mehr auf dem Server. / %lld Dokumente sind nicht mehr auf dem Server. |

`offlineUpToDate` and the three toasts exist in both `OfflineFeature` and `SettingsFeature`, which
is the intended duplication, and the two copies must stay identical.

Two strings are reworded rather than renamed:

- `swipeActionsLeadingFooter` — *In Favorites, removing the favorite always comes first* becomes
  *In Offline, removing the document always comes first* / *In Offline steht das Entfernen immer an
  erster Stelle.*
- `marketing.favorites` → `marketing.offline`, **values unchanged**: *Keep what matters, even
  offline* and *Wichtiges bleibt offline lesbar* already describe the renamed feature.

## §3 — The migration

Three pieces of persisted state carry the old name. Two are files; one is not, and it is the one
that fails quietly.

### The swipe action's raw value

`DocumentSwipeActionSettings.init(from:)` decodes through raw strings and `compactMap`s:

```swift
leading = try container.decodeIfPresent([String].self, forKey: .leading)?
    .compactMap(DocumentSwipeAction.init(rawValue:)) ?? defaults.leading
```

An unknown raw value is **dropped**, not defaulted — the `?? defaults` only covers a missing key.
Renaming the case would therefore leave anyone who had configured that swipe with a quietly emptied
edge: no crash, no fallback, a button that stopped existing. The decoder gains a legacy alias
applied before the `compactMap`, mapping `"favorite"` to `.saveOffline`, with a comment saying that
it is load-bearing rather than tidy. `DocumentSwipeActionTests` gets a case that decodes a stored
`"favorite"` and expects `.saveOffline`.

This is a decode-time alias, not a file rewrite: the settings file is rewritten in the new spelling
the first time the user changes anything, and until then it round-trips correctly.

### The two files

- `AppGroup/<server.id>-favorites.json` → `AppGroup/<server.id>-offline.json`
- `AppGroup/Favorites/<server.id>/` → `AppGroup/Offline/<server.id>/`

Getting this wrong orphans a user's downloaded PDFs — the list comes up empty and the bytes stay on
disk, invisible and unreclaimable.

`OfflineStorageMigration` in `ApiImplementation` does both, and needs **no server list**: it moves
the one `Favorites` directory, which carries every server's subdirectory inside it, and globs
`*-favorites.json` for the rest. Idempotent — a destination that already exists means the migration
has run, and the legacy path is left alone rather than overwritten.

It is called from `LessPaperApp.init()` **before the store is constructed**, because
`@Shared(.offlineDocuments(server))` is opened lazily by whichever state is built first and a read
that happens before the move would create an empty file at the new path and strand the old one. The
share extension touches neither path, so one process owns this and there is no coordination to get
right.

The migration is not removed after a release. It costs two `fileExists` calls on a cold launch, and
the alternative is deciding which version of the app a user is allowed to have skipped.

## §4 — Tests and assets

**Snapshot references.** `Snapshots/FavoritesFeatureTests/` → `Snapshots/OfflineFeatureTests/`, and
`Snapshots/SettingsFeatureTests/FavoriteSettingsViewTests/` likewise. One reference is named after
the test rather than the screen and renames with it:
`ServersFeatureTests/ServerDetailViewTests/testSnapshot_emptyCachesReadUnknownExceptFavorites.1.png`.
Every reference showing the
tab bar, the empty state, the detail's button or the Offline list is re-recorded with
`mise run snapshots:record`, and **looked at before being trusted** — a reference records whatever
the code produced, bug included.

**UI tests.** `SnapshotLabels.favorites` → `.offline`, `"Favorites"` → `"Offline"` and
`"Favoriten"` → `"Offline"`. `SnapshotTests.testFavorites` → `testOffline`, capturing `08-Offline`.
`AppPreviewTests` never navigates to this tab and needs no choreography change.

**App Store captures.** `MarketingScreen.offline` renames the file id to `08-Offline`, which the
framing step resolves against `Screenshots/Captures/`. The four committed captures are `git mv`d to
the new names in the same change, so `screenshots:frame` — which runs on any PR touching MarketingKit
or the captures — stays green on stale-but-correctly-named images until the re-record replaces them.
`verify_captures.py` counts eight screens per device and locale and does not read screen names, so
it is unaffected either way.

**The re-record** is its own change, after both UI changes have landed, because both alter what the
screenshots show and recording between them would spend the hour twice:
`screenshots:capture` → `screenshots:frame` → `screenshots:readme`, then `preview:record` for
`en-US` and `de-DE`. The preview video shows the tab bar throughout, so it is stale on the icon and
the label even though its choreography still passes.

## Sequencing

1. **`feat: offline, the tab that was Favorites`** — §2 and §3, plus the capture `git mv`. Mostly
   mechanical; the migration and the decoder alias are the parts that think.
2. **`feat: the documents search bar on the Offline list`** — §1. Small, and written in the final
   vocabulary.
3. **`chore: re-record the marketing assets after the offline rename`** — §4's re-record, through
   the existing manual workflows, which open their own pull requests.

## Risks

- **The migration is the only irreversible part.** A user who launches the new build has their files
  moved; a downgrade would not move them back. Tested against a fixture directory holding both
  layouts, plus the already-migrated case.
- **A missed `favorite` symbol compiles.** The string catalogue will catch a missing key at compile
  time, but a stale identifier in a comment or a test name will not. The sweep ends with a
  case-insensitive `favorit` grep over the tree, expected to return only this document and the older
  specs and plans under `docs/`, which are history and are left alone.
- **`tuist inspect dependencies --only implicit`** is the check a renamed module is most likely to
  trip, and tests cannot catch it. `mise run ci:lint` before pushing, as always.

## Out of scope

- The Documents list's search behaviour, which is unchanged.
- The Inbox, which has no search bar and is not given one here.
- Any change to what is stored offline, when it refreshes, or how much space it may take.
